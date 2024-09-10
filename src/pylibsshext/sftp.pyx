#
# This file is part of the pylibssh library
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, see file LICENSE.rst in this
# repository.

import os

from collections import deque
from posix.fcntl cimport O_CREAT, O_RDONLY, O_TRUNC, O_WRONLY

from cpython.bytes cimport PyBytes_AS_STRING
from cpython.mem cimport PyMem_Free, PyMem_Malloc

from pylibsshext.errors cimport LibsshSFTPException
from pylibsshext.session cimport get_libssh_session


MSG_MAP = {
    sftp.SSH_FX_OK: "No error",
    sftp.SSH_FX_EOF: "End-of-file encountered",
    sftp.SSH_FX_NO_SUCH_FILE: "File doesn't exist",
    sftp.SSH_FX_PERMISSION_DENIED: "Permission denied",
    sftp.SSH_FX_FAILURE: "Generic failure",
    sftp.SSH_FX_BAD_MESSAGE: "Garbage received from server",
    sftp.SSH_FX_NO_CONNECTION: "No connection has been set up",
    sftp.SSH_FX_CONNECTION_LOST: "There was a connection, but we lost it",
    sftp.SSH_FX_OP_UNSUPPORTED: "Operation not supported by the server",
    sftp.SSH_FX_INVALID_HANDLE: "Invalid file handle",
    sftp.SSH_FX_NO_SUCH_PATH: "No such file or directory path exists",
    sftp.SSH_FX_FILE_ALREADY_EXISTS: "An attempt to create an already existing file or directory has been made",
    sftp.SSH_FX_WRITE_PROTECT: "We are trying to write on a write-protected filesystem",
    sftp.SSH_FX_NO_MEDIA: "No media in remote drive"
}
cdef class SFTP:
    def __cinit__(self, session):
        self.session = session
        self._libssh_sftp_session = sftp.sftp_new(get_libssh_session(session))
        if self._libssh_sftp_session is NULL:
            raise LibsshSFTPException("Failed to create new session")
        if sftp.sftp_init(self._libssh_sftp_session) != libssh.SSH_OK:
            raise LibsshSFTPException("Error initializing SFTP session")

    def __dealloc__(self):
        if self._libssh_sftp_session is not NULL:
            sftp.sftp_free(self._libssh_sftp_session)
            self._libssh_sftp_session = NULL

    def put(self, local_file, remote_file):
        SFTP_AIO(self).put(local_file, remote_file)

    def get(self, remote_file, local_file):
        SFTP_AIO(self).get(remote_file, local_file)

    def close(self):
        if self._libssh_sftp_session is not NULL:
            sftp.sftp_free(self._libssh_sftp_session)
            self._libssh_sftp_session = NULL

    def _get_sftp_error_str(self):
        error = sftp.sftp_get_error(self._libssh_sftp_session)
        if error in MSG_MAP and error != sftp.SSH_FX_FAILURE:
            return MSG_MAP[error]
        return "Generic failure: %s" % self.session._get_session_error_str()

cdef sftp.sftp_session get_sftp_session(SFTP sftp_obj):
    return sftp_obj._libssh_sftp_session

cdef class SFTP_AIO:
    def __cinit__(self, SFTP sftp_obj):
        self._sftp = get_sftp_session(sftp_obj)

        self._limits = sftp.sftp_limits(self._sftp)
        if self._limits is NULL:
            raise LibsshSFTPException("Failed to get remote SFTP limits [%s]" % (self._get_sftp_error_str()))

    def __init__(self, SFTP sftp_obj):
        self._aio_queue = deque()

    def __dealloc__(self):
        if self._rf is not NULL:
            sftp.sftp_close(self._rf)
            self._rf = NULL

    def put(self, local_file, remote_file):
        # reset
        self._aio_queue = deque()
        self._total_bytes_requested = 0

        cdef C_AIO aio
        cdef sftp.sftp_file rf
        self._remote_file = remote_file

        remote_file_b = remote_file
        if isinstance(remote_file_b, unicode):
            remote_file_b = remote_file.encode("utf-8")

        rf = sftp.sftp_open(self._sftp, remote_file_b, O_WRONLY | O_CREAT | O_TRUNC, sftp.S_IRWXU)
        if rf is NULL:
            raise LibsshSFTPException("Opening remote file [%s] for write failed with error [%s]" % (remote_file, self._get_sftp_error_str()))
        self._rf = rf

        with open(local_file, "rb") as f:
            f.seek(0, os.SEEK_END)
            self._file_size = f.tell()
            f.seek(0, os.SEEK_SET)

            # start up to 10 requests before waiting for responses
            i = 0
            while i < 10 and self._total_bytes_requested < self._file_size:
                self._put_chunk(f)
                i += 1

            while len(self._aio_queue):
                aio = self._aio_queue.popleft()
                bytes_written = sftp.sftp_aio_wait_write(&aio.aio)
                if bytes_written == libssh.SSH_ERROR:
                    raise LibsshSFTPException(
                        "Failed to write to remote file [%s]: error [%s]" % (self._remote_file, self._get_sftp_error_str())
                    )
                # was freed in the wait if it did not fail
                aio.aio = NULL

                # whole file read
                if self._total_bytes_requested == self._file_size:
                    continue

                # else issue more read requests
                self._put_chunk(f)

            sftp.sftp_close(rf)
            self._rf = NULL

    def _put_chunk(self, f):
        to_write = min(self._file_size - self._total_bytes_requested, self._limits.max_write_length)
        buffer = f.read(to_write)
        if len(buffer) != to_write:
            raise LibsshSFTPException("Read only [%d] but requested [%d] when reading from local file [%s] " % (len(buffer), to_write, self._remote_file))

        cdef sftp.sftp_aio aio = NULL
        bytes_requested = sftp.sftp_aio_begin_write(self._rf, PyBytes_AS_STRING(buffer), to_write, &aio)
        if bytes_requested != to_write:
            raise LibsshSFTPException("Failed to write chunk of size [%d] of file [%s] with error [%s]"
                                      % (to_write, self._remote_file, self._get_sftp_error_str()))
        self._total_bytes_requested += bytes_requested
        c_aio = C_AIO()
        c_aio.aio = aio
        self._aio_queue.append(c_aio)

    def get(self, remote_file, local_file):
        # reset
        self._aio_queue = deque()
        self._total_bytes_requested = 0

        cdef C_AIO aio
        cdef sftp.sftp_file rf = NULL
        cdef sftp.sftp_attributes attrs
        cdef char *buffer = NULL
        self._remote_file = remote_file

        remote_file_b = remote_file
        if isinstance(remote_file_b, unicode):
            remote_file_b = remote_file.encode("utf-8")

        attrs = sftp.sftp_stat(self._sftp, remote_file_b)
        if attrs is NULL:
            raise LibsshSFTPException("Failed to stat the remote file [%s] with error [%s]"
                                      % (remote_file, self._get_sftp_error_str()))
        self._file_size = attrs.size

        buffer_size = min(self._limits.max_read_length, self._file_size)
        try:
            buffer = <char *>PyMem_Malloc(buffer_size)

            rf = sftp.sftp_open(self._sftp, remote_file_b, O_RDONLY, sftp.S_IRWXU)
            if rf is NULL:
                raise LibsshSFTPException("Opening remote file [%s] for reading failed with error [%s]" % (remote_file, self._get_sftp_error_str()))
            self._rf = rf

            with open(local_file, 'wb') as f:
                # start up to 10 write requests before waiting for responses
                i = 0
                while i < 10 and self._total_bytes_requested < self._file_size:
                    self._get_chunk()
                    i += 1

                while len(self._aio_queue):
                    aio = self._aio_queue.popleft()
                    bytes_read = sftp.sftp_aio_wait_read(&aio.aio, <void *>buffer, buffer_size)
                    if bytes_read == libssh.SSH_ERROR:
                        raise LibsshSFTPException(
                            "Failed to read from remote file [%s]: error [%s]" % (self._remote_file, self._get_sftp_error_str())
                        )
                    # was freed in the wait if it did not fail -- otherwise the __dealloc__ will free it
                    aio.aio = NULL

                    # write the file
                    f.write(buffer[:bytes_read])

                    # whole file read
                    if self._total_bytes_requested == self._file_size:
                        continue

                    # else issue more read requests
                    self._get_chunk()

        finally:
            if buffer is not NULL:
                PyMem_Free(buffer)
            sftp.sftp_close(rf)
            self._rf = NULL

    def _get_chunk(self):
        to_read = min(self._file_size - self._total_bytes_requested, self._limits.max_read_length)
        cdef sftp.sftp_aio aio = NULL
        bytes_requested = sftp.sftp_aio_begin_read(self._rf, to_read, &aio)
        if bytes_requested != to_read:
            raise LibsshSFTPException("Failed to request to read chunk of size [%d] of file [%s] with error [%s]"
                                      % (to_read, self._remote_file, self._get_sftp_error_str()))
        self._total_bytes_requested += bytes_requested
        c_aio = C_AIO()
        c_aio.aio = aio
        self._aio_queue.append(c_aio)


cdef class C_AIO:
    def __cinit__(self):
        self.aio = NULL

    def __dealloc__(self):
        sftp.sftp_aio_free(self.aio)
        self.aio = NULL
