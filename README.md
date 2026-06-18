# bundler-skills

A Bundler plugin that auto-symlinks AI agent skills bundled in your gems after
`bundle install`. The Ruby/Bundler counterpart of
[antfu/skills-npm](https://github.com/antfu/skills-npm).

> 🚧 Work in progress. See `.claude/plans/` for the implementation plan.

## Status

- [x] Phase 1: plugin skeleton + hook + production/CI disabling guard
- [ ] Phase 2: discovery + symlinking (Claude Code)
- [ ] Phase 3: multi-agent (Claude / Cursor / Codex / Copilot)
- [ ] Phase 4: `.gitignore` management
- [ ] Phase 5: full config
- [ ] Phase 6: `bundle skills` command
- [ ] Phase 7: docs
- [ ] Phase 8: integration tests + CI + release
