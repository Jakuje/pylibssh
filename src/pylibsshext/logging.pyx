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

import logging

from pylibsshext.errors cimport LibsshSessionException


ANSIBLE_PYLIBSSH_TRACE = 5

LOG_MAP = {
    logging.NOTSET: libssh.SSH_LOG_NONE,
    ANSIBLE_PYLIBSSH_TRACE: libssh.SSH_LOG_TRACE,
    logging.DEBUG: libssh.SSH_LOG_DEBUG,
    logging.INFO: libssh.SSH_LOG_INFO,
    logging.WARNING: libssh.SSH_LOG_WARN,
    logging.ERROR: libssh.SSH_LOG_WARN,
    logging.CRITICAL: libssh.SSH_LOG_WARN
}

LOG_MAP_REV = {
    libssh.SSH_LOG_NONE: logging.NOTSET,
    libssh.SSH_LOG_TRACE: ANSIBLE_PYLIBSSH_TRACE,
    libssh.SSH_LOG_DEBUG: logging.DEBUG,
    libssh.SSH_LOG_INFO: logging.INFO,
    libssh.SSH_LOG_WARN: logging.WARNING,
}

logger = logging.getLogger("libssh")


def add_trace_log_level():
    level_num = ANSIBLE_PYLIBSSH_TRACE
    level_name = "TRACE"
    method_name = level_name.lower()
    logger_class = logging.getLoggerClass()

    if hasattr(logging, level_name):
        raise AttributeError('{} already defined in logging module'.format(level_name))
    if hasattr(logging, method_name):
        raise AttributeError('{} already defined in logging module'.format(method_name))
    if hasattr(logger_class, method_name):
        raise AttributeError('{} already defined in logger class'.format(method_name))

    def logForLevel(self, message, *args, **kwargs):
        if self.isEnabledFor(level_num):
            self._log(level_num, message, args, **kwargs)

    def logToRoot(message, *args, **kwargs):
        logging.log(level_num, message, *args, **kwargs)

    logging.addLevelName(level_num, level_name)
    setattr(logging, level_name, level_num)
    setattr(logging, method_name, logToRoot)
    setattr(logger_class, method_name, logForLevel)


cdef void _pylibssh_log_wrapper(int priority,
                                const char *function,
                                const char *buffer,
                                void *userdata) noexcept nogil:
    with gil:
        log_level = LOG_MAP_REV[priority]
        logger.log(log_level, f"{buffer}")


def set_log_callback():
    callbacks.ssh_set_log_callback(_pylibssh_log_wrapper)


def logging_init():
    try:
        add_trace_log_level()
    except AttributeError:
        pass
    set_log_callback()


def set_level(level):
    logging_init()
    if level in LOG_MAP.keys():
        rc = libssh.ssh_set_log_level(LOG_MAP[level])
        if rc != libssh.SSH_OK:
            raise LibsshSessionException("Failed to set log level [%d] with error [%d]" % (level, rc))
        logger.setLevel(level)
    else:
        raise LibsshSessionException("Invalid log level [%d]" % level)
