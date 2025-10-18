# -*- coding: utf-8 -*-

"""Version definition."""

from ._libssh_version import (  # noqa: N811, WPS300
    LIBSSH_VERSION as __libssh_version__,
)


try:
    from ._scm_version import version as __version__  # noqa: WPS300
except ImportError:
    from pkg_resources import get_distribution as _get_dist

    __version__ = _get_dist('ansible-pylibssh').version


__full_version__ = (
    '<pylibsshext v{wrapper_ver!s} with libssh v{backend_ver!s}>'.format(
        wrapper_ver=__version__,
        backend_ver=__libssh_version__,
    )
)
__version_info__ = tuple(
    (int(chunk) if chunk.isdigit() else chunk)
    for chunk in __version__.split('.')
)
