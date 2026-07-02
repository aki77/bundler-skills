# bundler-skills

A gem that auto-symlinks **AI agent skills bundled in your gems** into your
project on `bundle install`. The Ruby/Bundler counterpart of
[antfu/skills-npm](https://github.com/antfu/skills-npm).

Gems ship `skills/<name>/SKILL.md`; your project links them into the right agent
directory so the skill version always matches the gem version, and your whole
team gets them just by running `bundle install`.

## How it works

bundler-skills is installed **globally** into your Ruby and ships a RubyGems
`post_install` hook (via `lib/rubygems_plugin.rb`). RubyGems loads that hook for
every `bundle install`, but it only does anything when the project has **opted
in** by placing a `bundler-skills.yml` in its root — projects without that file
are left completely untouched. Whenever a gem is **actually installed** during
`bundle install` / `bundle update` in an opted-in project, the hook runs for
that gem and:

1. Scans **that gem** for `skills/*/SKILL.md`.
2. Detects which agents you use (by marker directories) and symlinks each skill
   into the right place, named `gem-<gem>--<skill>`.
3. Prunes that gem's own stale links (so a version that renames or drops a skill
   updates correctly), leaving every other gem's links untouched.
4. Adds the generated symlink patterns to `.gitignore` (they are machine-local).

A `bundle install` that installs nothing (everything already cached) does no
work — only freshly installed gems are processed. To re-sync everything at once
(e.g. after removing a gem, or right after adding `bundler-skills.yml` to an
existing project), run `bundler-skills sync` (see below).

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

bundler-skills is a **global** tool, not a project dependency — it is not added
to your `Gemfile`. Install it once into your Ruby:

```sh
gem install bundler-skills
```

Then, in each project where you want it active, opt in by creating a
`bundler-skills.yml` in the project root:

```sh
cd my-project
bundler-skills init   # writes an all-defaults bundler-skills.yml
```

That single file is the opt-in switch: only projects that contain it are
touched by the `post_install` hook, so every other project sharing the same
Ruby is left alone.

From then on, when a skill-bearing gem is freshly installed by `bundle install`
you'll see something like:

```
[bundler-skills] 1 skill(s) discovered, 1 linked, 0 relinked, 0 pruned across 1 dir(s) (agents: claude)
  created:
    .claude/skills/gem-rubocop--style  ->  /path/to/gems/rubocop/skills/style
```

> **Adding it to an existing project?** The `post_install` hook only fires for
> gems that are **freshly installed**. If your gems are already installed (the
> common case when you add `bundler-skills.yml` after the fact), a `bundle
> install` is a no-op and links nothing. Run `bundler-skills sync` once to link
> what's already there.

> In production / CI you generally don't need it: don't install the gem there,
> or omit `bundler-skills.yml` from the deploy, or force it off anywhere with
> `BUNDLER_SKILLS_DISABLED=1`. The generated symlinks are gitignored, so they
> aren't shipped either way.

When a run actually changes something (links created, relinked after a gem
update, or stale links pruned) the summary is printed in green so it stands out;
a run with nothing to do prints the same line in plain text. A changed run also
lists each affected skill, grouped by kind, with the path to its `SKILL.md` so
you can review the (third-party) skill contents now linked into your project.

## The `bundler-skills` command

`gem install bundler-skills` puts a `bundler-skills` executable on your PATH.
The `post_install` hook only fires for gems that are freshly installed, so to
re-sync everything at once — after adding `bundler-skills.yml` to an existing
project, after removing a gem, after `bundle lock` (which installs nothing), or
just to inspect/clean — run it from the project root:

```sh
bundler-skills          # (or: bundler-skills sync) re-scan ALL gems and (re)create symlinks
bundler-skills list     # show discovered skills and target agents (no changes)
bundler-skills clean    # remove all gem-*--* symlinks this gem created
bundler-skills init     # create a bundler-skills.yml config file with defaults
bundler-skills <cmd> --dry-run   # show what would change without writing
```

It resolves the current project via `Bundler.root`, so run it from anywhere
inside the project. Unlike the automatic hook, `sync` scans every resolved gem
and prunes any stale `gem-*--*` link (so it also cleans up after a removed gem).
It always runs and ignores both the `bundler-skills.yml` opt-in and
`BUNDLER_SKILLS_DISABLED`, since invoking it is an explicit action.

## Configuration

`bundler-skills.yml` in your project root is **required** to opt in (an empty
file is fine — it means "all defaults"). Every key inside it is optional:

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
  gitignored and re-created on each machine's `bundle install`.

### Disabling

Set `BUNDLER_SKILLS_DISABLED` to a truthy value (`1`/`true`/`yes`/`on`) to turn
the `post_install` hook off without removing `bundler-skills.yml`. There is no
production/CI auto-detection: the primary scope control is the opt-in file
itself — omit it and the hook does nothing. The manual `bundler-skills` command
ignores this switch (and the opt-in file).

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
- The hook fires only in projects that opt in with a `bundler-skills.yml`.
- The `post_install` hook only fires for gems that are **actually installed**. A
  cached `bundle install` (nothing to install) and `bundle lock` do no syncing —
  run `bundler-skills sync` to re-sync on demand.
- When a gem is **removed**, no hook fires for it, so its `gem-*--*` links linger
  until the next `bundler-skills sync` (full sync prunes them).

## Development

```sh
bundle install
bundle exec rake test          # unit tests
bundle exec rake integration   # real bundle install end-to-end
```

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
