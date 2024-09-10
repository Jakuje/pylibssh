# distutils: libraries = ssh
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
#
from pylibsshext.includes cimport libssh, sftp
from pylibsshext.session cimport Session


cdef class SFTP:
    cdef Session session
    cdef sftp.sftp_session _libssh_sftp_session

cdef class SFTP_AIO:
    cdef _aio_queue
    cdef _remote_file
    cdef _file_size
    cdef _total_bytes_requested
    cdef sftp.sftp_session _sftp
    cdef sftp.sftp_limits_t _limits
    cdef sftp.sftp_file _rf

cdef class C_AIO:
    cdef sftp.sftp_aio aio
