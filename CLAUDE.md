# MacCursor

Free, open-source macOS cursor highlighter. See `IDEA.md` for the product idea.

## Workflow: agent-skills

This project is managed with [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills),
installed as the project-scoped plugin `agent-skills@addy-agent-skills` (see `.claude/settings.json`).

- Follow its lifecycle: `/spec` → `SPEC.md`, `/plan` → `tasks/plan.md` + `tasks/todo.md`,
  then `/build`, `/test`, `/agent-skills:review`, `/code-simplify`, `/ship`.
- Use its skills (spec-driven-development, planning-and-task-breakdown,
  incremental-implementation, test-driven-development, etc.) for process.
- The globally installed Superpowers plugin is disabled for this project
  (`"superpowers@claude-plugins-official": false` in `.claude/settings.json`).
  Don't re-enable it or use its workflows here.
- The user sequences the work. Don't move to the next lifecycle phase until asked.
