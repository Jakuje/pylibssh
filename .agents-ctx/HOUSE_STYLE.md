# House Style

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
