# -*- coding: utf-8 -*-

"""Tests suite for session."""

import logging

import pytest

from pylibsshext.errors import LibsshSessionException
from pylibsshext.logging import ANSIBLE_PYLIBSSH_TRACE
from pylibsshext.session import Session


LOCALHOST = '127.0.0.1'


def test_make_session():
    """Smoke-test Session instance creation."""
    assert Session()


def test_session_connection_refused(free_port_num):
    """Test that connecting to a missing service raises an error."""
    error_msg = '^ssh connect failed: Connection refused$'
    ssh_session = Session()
    with pytest.raises(LibsshSessionException, match=error_msg):
        ssh_session.connect(host=LOCALHOST, port=free_port_num)


def test_session_log_level_debug(caplog, free_port_num):
    """Test setting the log level to DEBUG should reveal copyright information."""
    ssh_session = Session()
    ssh_session.set_log_level(logging.DEBUG)

    # the connection will fail but first log lands before that
    with pytest.raises(LibsshSessionException):
        ssh_session.connect(host=LOCALHOST, port=free_port_num)

    found_copyright = False
    for record in caplog.records:
        # This log message is shown at different log levels in different libssh versions
        if record.levelname in {'DEBUG', 'INFO'} and 'and libssh contributors.' in record.msg:
            found_copyright = True
    assert found_copyright


def test_session_log_level_no_log(caplog, free_port_num):
    """Test setting the log level to NONE should be quiet."""
    ssh_session = Session()
    ssh_session.set_log_level(logging.NOTSET)

    # the connection will fail but first log lands before that
    with pytest.raises(LibsshSessionException):
        ssh_session.connect(host=LOCALHOST, port=free_port_num)

    assert not caplog.records


def test_session_log_level_trace(caplog, free_port_num):
    """Test setting the log level to TRACE should provide even more logs."""
    ssh_session = Session()
    ssh_session.set_log_level(ANSIBLE_PYLIBSSH_TRACE)

    # the connection will fail but first log lands before that
    with pytest.raises(LibsshSessionException):
        ssh_session.connect(host=LOCALHOST, port=free_port_num)

    found_trace = False
    for record in caplog.records:
        if record.levelname == 'TRACE' and 'ssh_socket_pollcallback: Poll callback on socket' in record.msg:
            found_trace = True
    assert found_trace
