# Changelog

## [Unreleased]

### Changed (breaking)

- **Opt-in is now the presence of a `bundler-skills.yml` in the project root**,
  not membership in the `Gemfile`. bundler-skills is installed **globally**
  (`gem install bundler-skills`) and activated per project by that file. This
  fixes the real bug where the global RubyGems `post_install` hook fired for
  *every* project sharing the Ruby — including ones not using bundler-skills at
  all — and wrote its managed block into their `.gitignore`. Projects without a
  `bundler-skills.yml` are now left completely untouched. No backward
  compatibility: the old "add it to the Gemfile and it just works" behavior is
  gone.
- **Renamed the executable `skills` → `bundler-skills`** to avoid clashing with
  other tools now that it is installed globally on PATH. Invoke it as
  `bundler-skills [sync|list|clean|init]` (no `bundle exec` needed).

### Fixed

- The global executable now `require`s `bundler`, so running `bundler-skills`
  directly (not via `bundle exec`) no longer crashes resolving `Bundler.root`.
- `.gitignore` is left untouched when a run discovers no skills (belt-and-braces
  against writing the managed block into projects with no skill-bearing gems).

## [0.5.0] - 2026-06-27

### Changed (breaking)

- Drop support for Ruby 3.1 and 3.2 (both EOL). Minimum required Ruby is now 3.3.

### Changed

- The post-install summary now stays silent when a run discovers no skills and
  changes nothing. The `Gem.post_install` hook fires for every installed gem,
  most of which ship no skills, so the previous `0 skill(s) discovered, 0 linked
  ...` line was pure noise on each one.

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
