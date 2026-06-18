# Changelog

## [Unreleased]

## [0.1.0] - 2026-06-18

### Added

- Initial release of `bundler-skills`.
- `after-install-all` hook that discovers `skills/*/SKILL.md` in dependency gems
  and symlinks them into agent skill directories after `bundle install`.
- Multi-agent support: Claude Code (`.claude/skills`), Cursor / Codex / GitHub
  Copilot (`.agents/skills`), detected by marker directories.
- `gem-<gem>--<skill>` double-hyphen link naming (unambiguous for hyphenated gem
  names).
- Idempotent linking, stale prune, and `.gitignore` management.
- Automatic disabling in production / CI (`RAILS_ENV`/`RACK_ENV=production`,
  `CI`, `BUNDLER_SKILLS_DISABLED`); override with `BUNDLER_SKILLS_ENABLED`.
- `bundle skills` command (`sync` / `list` / `clean`, with `--dry-run`).
- `bundler-skills.yml` configuration (`enabled`, `agents`, `gitignore`,
  `cleanup`, `recursive`, `include`, `exclude`).
