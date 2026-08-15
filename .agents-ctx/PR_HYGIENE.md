# PR & Commit Hygiene

Grounded in the project's own review history, plus explicit
maintainer conventions carried over from other projects — not
guesses.

## Point contributors to the official guidelines

Route contributors to
<https://ansible-pylibssh.rtfd.io/en/latest/contributing/guidelines>
for the canonical contribution process, rather than improvising or
restating it secondhand.

## Keep PRs and commits atomic and scoped

One conceptual change per PR, one conceptual change per commit.
"I'm definitely not going to accept a bunch of unrelated changes
smashed together" (PR #809); a PR mixing formatting, docstring
rewording, and a behavior change got split into three (PR #862)
before being accepted. Rebase onto the target branch for real
instead of adding merge commits ("foxtrot merges") to a feature
branch.

## Don't dump AI-generated bloat

"LLMs are good at generating way too much stuff and it even works
under some circumstances but we're still responsible for keeping
the patches maintainable, having Git tree tell a story and contain
sufficient context. Be accountable." (PR #790) -- trim anything not
directly related to the stated change before proposing it.

## Every change needs a changelog fragment

One fragment per PR, filed under `docs/changelog-fragments/` as
`<issue/PR#>.<type>.rst`.

A changelog fragment is not a restated commit message -- it covers
everything since the previous release, for end-users, not
developers. See `docs/changelog-fragments/README.rst` for the full
rationale, including why changelog entries are a permanent
historical record (never retroactively removed, even if the
underlying code is later reverted) unlike commit history, which
can be reworded, rebased, or squashed.

Recurring, specific review feedback:

- One change per fragment, not several changes "smashed" into one
  (#756, #862).
- Wording is past-tense and end-user-facing, not
  imperative/developer-facing.
- Reference related issues/PRs using `sphinx-issues` roles
  (`:pr:`, `:user:`, `:file:`) instead of raw links or backticks
  (#620, #786, #790, #809).

## Names and docstrings carry the meaning, not comments

"Comments repeating what the code does are pointless. Proper
identifier names should be used instead" (PR #621). Docstrings
describe what a function does; motivation/rationale, if needed,
belongs in a comment or the PR description, not the docstring
(PR #658).

## Common micro-conventions flagged in review

- f-strings over `.format()`/`%` formatting.
- `contextlib.suppress()` over bare `try`/`except: pass`.
- No monkey-patching stdlib.
- Type annotations required on new/touched code; alias
  `import typing as _t` for standard-library typing constructs
  (e.g. `_t.Optional[...]`).
- Public vs. private intent must be explicit -- prefix with `_` if
  not part of the public API.
