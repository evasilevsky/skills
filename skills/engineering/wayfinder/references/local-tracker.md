# Local-Markdown Issue Tracker

Use this when wayfinder is invoked on a repo with no GitHub/GitLab remote (or the user prefers local files). The issue tracker lives as markdown files under `.scratch/` in the workspace.

## Convention

- Map issue: `.scratch/<name>/map.md` (where `<name>` is the effort name, e.g. `nas-ai-integration`)
- Child tickets: `.scratch/<name>/tickets/ticket-NNN-<slug>.md`
- Each ticket body follows the wayfinder ticket format:

```
## Question

<the decision or investigation>

## Resolution

**Facts discovered:**

1. ...

## Answer

<the decision>

## Constraints

<if any>
```

- Map Decisions-so-far: append one-line gists as the user reads them back
- Not yet specified: the fog section on the map, updated as tickets resolve

## Workflow

1. Create the `.scratch/<name>/` directory.
2. Create the map file with Destination, Notes, Decisions-so-far (empty), Not yet specified.
3. Create tickets as child files under `.scratch/<name>/tickets/`.
4. Resolve tickets by filling in the `## Resolution`, `## Answer`, and `## Constraints` sections.
5. Update the map's Decisions-so-far with context pointers (relative links to the ticket).
6. Graduate fog into new tickets, create-then-wire (ticket then blocking).

## Notes

- No blocking edges can be enforced locally (no native dependency model). Record blocking as text in ticket bodies or in the map.
- This is the default when no tracker is configured — the user should know this is a fallback to GitHub/GitLab for multi-agent work.
- The local tracker works fine for single-agent sessions or when the user prefers not to use GitHub.
