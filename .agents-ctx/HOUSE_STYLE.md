# House Style

Grounded in the project's own review history, plus explicit
maintainer conventions carried over from other projects — not
guesses.

## No new `@`-syntax in memory files

Do not introduce additional Claude `@`-mention/import syntax inside
any file under `.agents-ctx/`. The existing chain (`CLAUDE.md` ->
`AGENTS.md` -> `.agents-ctx/HOUSE_RULES.md`) is the only sanctioned
use of `@`-imports.

`@`-mentions load eagerly, at the start of every session, whether
or not the content ends up being relevant. Everything reachable
from `HOUSE_RULES.md` onward links to further material with plain
Markdown links instead, so an agent can pull it into context on
demand -- when a task actually needs it -- rather than having the
whole tree pollute the context window up front.

## Keep encoded-bytes objects alive when backing a `char*`

Assigning an intermediate result straight into a `char*`/`const
char*` (e.g. `cdef char* c_buf = value.encode("utf-8")`) is a
segfault waiting to happen: the encoded `bytes` object has no
Python reference keeping it alive, so it can be garbage-collected
while the pointer is still in use, leaving `c_buf` dangling.
Assign the encoded bytes to a named Python variable first and
keep that variable alive for as long as the pointer is used. When
you do this, add a code comment explaining why, citing Cython's
own docs on the gotcha:
https://cython.readthedocs.io/en/latest/src/tutorial/strings.html#encoding-text-to-bytes
(PR #875).

## Cython still shims the removed Python 2 `unicode` name

Even under `language_level = 3`, Cython keeps `unicode` available
as a shim for `str`
(https://cython.readthedocs.io/en/latest/src/tutorial/strings.html#python-string-types-in-cython-code),
which reads as confusing coming from plain Python 3, where
`unicode` doesn't exist. Don't be surprised to see it in Cython
code or docs, but don't introduce new uses of it -- prefer `str`.

A related open TODO, not yet acted on: unifying the
`language_level` compiler directive to a single explicit value
across the codebase, rather than leaving it implicit/inconsistent
(PR #875).

## `str | bytes`-style type hints aren't enforced at runtime here

Union type annotations on Cython-extension methods (e.g. `data:
str | bytes`) aren't actually enforced at runtime by
CPython/Cython -- they have the same effect as a docstring, not
real validation. Don't treat a Union annotation as a substitute
for actual input-coercion/validation logic (PR #870/#874
discussion).

## No automated formatter for `.pyx` -- wrap long lines by hand

Unlike `.py` files (formatted by `ruff format`), there's
currently no formatter tool that works on Cython source. Long-line
wrapping in `.pyx` files is done by hand, following ordinary
Python-style continuation conventions -- not C-style formatting
habits (PR #869).
