# Changelog

## [Unreleased]

## [0.4.0] - 2026-06-27

### Changed (breaking)

- **bundler-skills is now a regular gem, not a Bundler plugin.** Install it as
  `gem "bundler-skills"` (recommended: in the `development` group) instead of
  `plugin "bundler-skills"`. This removes the `Bundler::Plugin::Index::CommandConflict`
  that occurred (and recurred on every `bundle` run until `bundler plugin
  uninstall`) whenever `bundle update` bumped bundler-skills itself.
- Syncing now runs from a RubyGems `Gem.post_install` hook
  (`lib/rubygems_plugin.rb`): when a gem is actually installed during
  `bundle install` / `bundle update`, only **that gem's** skills are linked, and
  only that gem's own stale links are pruned (other gems are untouched). A
  cached `bundle install` that installs nothing does no work.
- The manual command moved from the Bundler subcommand `bundle skills` to the
  plain executable **`bundle exec skills`** (`sync` / `list` / `clean` / `init`,
  with `--dry-run`). `skills sync` scans all gems and prunes all stale links.

### Removed

- Production / CI auto-detection (`RAILS_ENV`/`RACK_ENV=production`, `CI`) and the
  `enabled:` config key / `BUNDLER_SKILLS_ENABLED` override. With a
  development-group install the gem isn't present in production/CI anyway. The
  only switch left is `BUNDLER_SKILLS_DISABLED`.

## [0.3.0] - 2026-06-21

### Changed

- Post-install summary now highlights runs that actually changed something:
  when skills are created, relinked (after a gem update), or pruned, the summary
  line is printed in green (`confirm`) instead of plain text, and the count of
  relinked skills is now shown alongside linked/pruned.
- A changed run additionally lists each affected skill grouped by kind
  (created / relinked / pruned), showing the path to its `SKILL.md`, so the
  third-party skill contents linked into your project are easy to review.

## [0.2.0] - 2026-06-18

### Added

- `bundle skills init` command: creates a `bundler-skills.yml` config file with
  all keys commented out, so users can enable only the options they need.

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
