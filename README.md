# bundler-skills

A gem that symlinks **AI agent skills bundled in your gems** into your project.
The Ruby/Bundler counterpart of
[antfu/skills-npm](https://github.com/antfu/skills-npm).

Gems ship `skills/<name>/SKILL.md`; running `bundle exec skills` links them into
the right agent directory so the skill version always matches the gem version.

## How it works

bundler-skills is a regular gem that ships a `bundle exec skills` command.
**Nothing runs automatically** — there is no `bundle install` hook. Sync happens
only when you run the command (manually, or from a git hook you set up). Each run:

1. Scans **all dependency gems** for `skills/*/SKILL.md`.
2. Detects which agents you use (by marker directories) and symlinks each skill
   into the right place, named `gem-<gem>--<skill>`.
3. Prunes stale `gem-*--*` links (so a gem that renames, drops, or is removed
   updates correctly).
4. Adds the generated symlink patterns to `.gitignore` (they are machine-local).

Run it whenever your dependencies change — right after `bundle install` /
`bundle update` — either by hand or from a git hook (see
[Running automatically](#running-automatically-git-hooks--hook-managers)).

### Supported agents

| Agent          | Output directory  | Detected when present |
| -------------- | ----------------- | --------------------- |
| Claude Code    | `.claude/skills/` | `.claude/`            |
| Cursor         | `.agents/skills/` | `.cursor/`            |
| Codex          | `.agents/skills/` | `.codex/` or `AGENTS.md` |
| GitHub Copilot | `.agents/skills/` | `.github/`            |

`.agents/skills/` is the cross-tool standard shared by Cursor / Codex / Copilot;
Claude Code needs its own `.claude/skills/` because it does not read
`.agents/skills/` yet. It links into a directory only when that agent's marker
exists, so nothing is created in projects that don't use these tools.

## Installation

Add the gem to your `Gemfile`, in the `development` group (skills are a
development-time concern; this is the recommended, team-wide way):

```ruby
# Gemfile
source "https://rubygems.org"

group :development do
  gem "bundler-skills"
end

gem "some-gem-that-ships-skills"
```

Then install and run the command:

```sh
bundle install
bundle exec skills
```

When a skill-bearing gem is present you'll see something like:

```
[bundler-skills] 1 skill(s) discovered, 1 linked, 0 relinked, 0 pruned across 1 dir(s) (agents: claude)
  created:
    .claude/skills/gem-rubocop--style  ->  /path/to/gems/rubocop/skills/style
```

> In production / CI you typically run `bundle install` with the `development`
> group excluded (`bundle config set --local without development`), and you
> simply don't run `bundle exec skills` there — nothing happens unless you invoke it.

When a run actually changes something (links created, relinked after a gem
update, or stale links pruned) the summary is printed in green so it stands out;
a run with nothing to do prints the same line in plain text. A changed run also
lists each affected skill, grouped by kind, with the path to its `SKILL.md` so
you can review the (third-party) skill contents now linked into your project.

## Running automatically (git hooks / hook managers)

Sync is manual by design, but you'll usually want it to run right after your
dependencies change (`bundle install` / `bundle update`, i.e. whenever
`Gemfile.lock` changes). Wire the one-liner into a git hook or hook manager:

Plain git hook — create `.git/hooks/post-merge` (also useful as `post-checkout`
/ `post-rewrite`) and `chmod +x` it. Note `.git/hooks` is not committed, so this
is per-clone:

```sh
#!/bin/sh
bundle exec skills
```

[lefthook](https://github.com/evilmartians/lefthook) — committed, shared with
the team:

```yaml
# lefthook.yml
post-merge:
  commands:
    skills: { run: bundle exec skills }
post-checkout:
  commands:
    skills: { run: bundle exec skills }
```

[husky](https://typicode.github.io/husky/) — for JS-mixed projects, create
`.husky/post-merge`:

```sh
#!/usr/bin/env sh
bundle exec skills
```

[overcommit](https://github.com/sds/overcommit) — for Ruby projects:

```yaml
# .overcommit.yml
PostCheckout:
  BundlerSkills:
    enabled: true
    command: ['bundle', 'exec', 'skills']
```

## The `bundle exec skills` command

Sync happens only when you run this command. Run it after your dependencies
change, or just to inspect / clean up:

```sh
bundle exec skills          # (sync) re-scan ALL gems and (re)create symlinks — the default
bundle exec skills sync     # explicit form of the default
bundle exec skills list     # show discovered skills and target agents (no changes)
bundle exec skills clean    # remove all gem-*--* symlinks this gem created
bundle exec skills init     # create a bundler-skills.yml config file with defaults
bundle exec skills <cmd> --dry-run   # show what would change without writing
```

`sync` scans every resolved gem and prunes any stale `gem-*--*` link, so it also
cleans up after a removed gem.

## Configuration

All optional. Create `bundler-skills.yml` in your project root:

```yaml
agents:                     # omit = auto-detect; or list: [claude, cursor]; or "*"
  - claude
  - cursor
gitignore: true             # manage .gitignore (default true)
cleanup: true               # prune stale gem-*--* links (default true)
recursive: false            # also scan skills/**/SKILL.md (default false)
include:                    # only these gems (empty = all). fnmatch on "gem" or "gem/skill"
  - rubocop
  - "rails-*"
exclude:                    # exclude these (wins over include)
  - some-noisy-gem
```

Notes:

- The link target is the gem's path on your machine; that's why the symlinks are
  gitignored and re-created on each machine (run `bundle exec skills` after
  `bundle install`).

## Naming: `gem-<gem>--<skill>`

The boundary between gem name and skill name is a **double hyphen** (`--`) so a
gem name that itself contains hyphens stays unambiguous:

```
gem-rails-html-sanitizer--escaping
    └── gem: rails-html-sanitizer ──┘└ skill: escaping
```

RubyGems names cannot contain consecutive hyphens, so `--` is always a safe
delimiter. (This is an intentional improvement over skills-npm's `npm-` naming.)

## For gem authors

See [PROPOSAL.md](PROPOSAL.md) for the distribution convention. In short: put
`skills/<name>/SKILL.md` in your gem and include `skills/` in your gemspec
`files`.

## Trust boundary

Skills bundled in third-party gems are third-party content. This gem only
**creates symlinks** to them — it never executes their contents. Reviewing what a
skill instructs your agent to do is the user's responsibility, the same as
reviewing any dependency.

## Limitations

- POSIX symlinks are assumed; Windows is not supported yet.
- Whether Cursor / Codex / Copilot follow symlinked `SKILL.md` during their own
  directory scans is not formally documented; verified working with Claude Code.
- Syncing is not automatic. Run `bundle exec skills` after your dependencies
  change (manually, or from a git hook — see above).
- Removing a gem leaves its `gem-*--*` links until the next `bundle exec skills`,
  which prunes them.

## Development

```sh
bundle install
bundle exec rake test          # unit tests
bundle exec rake integration   # real bundle install end-to-end
```

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
