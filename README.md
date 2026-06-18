# bundler-skills

A Bundler plugin that auto-symlinks **AI agent skills bundled in your gems**
into your project after `bundle install`. The Ruby/Bundler counterpart of
[antfu/skills-npm](https://github.com/antfu/skills-npm).

Gems ship `skills/<name>/SKILL.md`; your project links them into the right agent
directory so the skill version always matches the gem version, and your whole
team gets them just by running `bundle install`.

## How it works

After `bundle install` / `bundle update`, the plugin:

1. Scans your resolved dependency gems for `skills/*/SKILL.md`.
2. Detects which agents you use (by marker directories) and symlinks each skill
   into the right place, named `gem-<gem>--<skill>`.
3. Adds the generated symlink patterns to `.gitignore` (they are machine-local).

It is **disabled automatically in production/CI** — skills are a development-time
concern.

### Supported agents

| Agent          | Output directory  | Detected when present |
| -------------- | ----------------- | --------------------- |
| Claude Code    | `.claude/skills/` | `.claude/`            |
| Cursor         | `.agents/skills/` | `.cursor/`            |
| Codex          | `.agents/skills/` | `.codex/` or `AGENTS.md` |
| GitHub Copilot | `.agents/skills/` | `.github/`            |

`.agents/skills/` is the cross-tool standard shared by Cursor / Codex / Copilot;
Claude Code needs its own `.claude/skills/` because it does not read
`.agents/skills/` yet. The plugin links into a directory only when that agent's
marker exists, so nothing is created in projects that don't use these tools.

## Installation

Add the plugin to your `Gemfile` (this is the recommended, team-wide way):

```ruby
# Gemfile
source "https://rubygems.org"

plugin "bundler-skills"

gem "some-gem-that-ships-skills"
```

Then:

```sh
bundle install
```

That's it. On install you'll see something like:

```
[bundler-skills] 3 skill(s) discovered, 3 linked, 0 pruned across 1 dir(s) (agents: claude)
```

> Alternatively, install it globally with `bundle plugin install bundler-skills`.
> The `Gemfile` approach is preferred because it propagates to the whole team.

## The `bundle skills` command

`bundle install` triggers syncing automatically, but `bundle lock` does **not**
run plugin hooks ([rubygems#7542](https://github.com/ruby/rubygems/issues/7542)).
Use the command to sync manually, or to inspect/clean:

```sh
bundle skills          # (or: bundle skills sync) re-create symlinks
bundle skills list     # show discovered skills and target agents (no changes)
bundle skills clean    # remove all gem-*--* symlinks this plugin created
bundle skills <cmd> --dry-run   # show what would change without writing
```

Unlike the automatic hook, the command always runs (it ignores the
production/CI guard) since invoking it is an explicit action.

## Configuration

All optional. Create `bundler-skills.yml` in your project root:

```yaml
enabled:                    # nil (auto) | false (off) | [development] (env list)
agents:                     # omit = auto-detect; or list: [claude, cursor]; or "*"
  - claude
  - cursor
gitignore: true             # manage .gitignore (default true)
cleanup: true               # prune stale gem-*--* links when a gem is removed (default true)
recursive: false            # also scan skills/**/SKILL.md (default false)
include:                    # only these gems (empty = all). fnmatch on "gem" or "gem/skill"
  - rubocop
  - "rails-*"
exclude:                    # exclude these (wins over include)
  - some-noisy-gem
```

Notes:

- Skills from `development`/`test` group gems are included by default — those are
  exactly the gems (linters, test helpers) that ship skills. They are only
  excluded when your environment sets `bundle config set without development`
  (e.g. production), in which case skills aren't wanted anyway.
- The link target is the gem's path on your machine; that's why the symlinks are
  gitignored and re-created on each machine's `bundle install`.

### Disabling

The hook is off automatically when any of these hold:

- `BUNDLER_SKILLS_DISABLED` is set to a truthy value
- `RAILS_ENV` / `RACK_ENV` is `production`
- `CI` is truthy
- `bundler-skills.yml` has `enabled: false`, or `enabled: [..]` not listing the
  current env

Force it on with `BUNDLER_SKILLS_ENABLED=1` or `enabled: true`.

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

Skills bundled in third-party gems are third-party content. This plugin only
**creates symlinks** to them — it never executes their contents. Reviewing what a
skill instructs your agent to do is the user's responsibility, the same as
reviewing any dependency.

## Limitations

- POSIX symlinks are assumed; Windows is not supported yet.
- Whether Cursor / Codex / Copilot follow symlinked `SKILL.md` during their own
  directory scans is not formally documented; verified working with Claude Code.

## Development

```sh
bundle install
bundle exec rake test          # unit tests
bundle exec rake integration   # real bundle install end-to-end
```

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
