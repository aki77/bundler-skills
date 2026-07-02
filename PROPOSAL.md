# Distributing Agent Skills in gems

This document describes how a gem author ships **AI agent skills** so that
[bundler-skills](README.md) (and, by convention, any compatible tool) can
discover and link them.

## Convention

Put a `skills/` directory at the root of your gem. Each immediate subdirectory
is one skill and must contain a `SKILL.md` following the
[Agent Skills](https://code.claude.com/docs/en/skills) format (YAML frontmatter
with at least `name` and `description`, then Markdown body):

```
my-gem/
├── my-gem.gemspec
├── lib/
│   └── my_gem.rb
└── skills/
    └── my-gem-helper/
        └── SKILL.md
```

```markdown
---
name: my-gem-helper
description: How to use my-gem's DSL correctly, with common patterns.
---

# my-gem helper

... instructions for the agent ...
```

## Package the skills

The `skills/` directory must be part of the published gem, so include it in the
gemspec `files`:

```ruby
# my-gem.gemspec
Gem::Specification.new do |spec|
  # ...
  spec.files += Dir["skills/**/*"]
end
```

If your gemspec builds `files` from `git ls-files`, committed skill files are
included automatically — just make sure they aren't gitignored.

## What consumers get

When a project depends on your gem and uses bundler-skills, each skill is
symlinked into the project's agent directory as:

```
gem-<your-gem-name>--<skill-name>
```

For example `skills/my-gem-helper/SKILL.md` in `my-gem` becomes
`.claude/skills/gem-my-gem--my-gem-helper` (and/or `.agents/skills/...`).

The double-hyphen `--` separates the gem name from the skill name. Because
RubyGems names cannot contain consecutive hyphens, the boundary is unambiguous
even for gems like `rails-html-sanitizer`.

## Guidelines

- **One concern per skill.** Keep each `skills/<name>/` focused; the `name` and
  `description` frontmatter is what an agent uses to decide relevance.
- **Skill name = directory name.** The subdirectory name becomes the skill name
  in the symlink, so keep it stable and descriptive.
- **Version together.** The whole point is that skills ship and update with the
  exact version of your gem — treat `SKILL.md` as part of your public surface.
- **Assets / scripts.** Anything alongside `SKILL.md` in the skill directory is
  linked too (the directory is symlinked as a whole), so reference relative
  files normally.

## Why an explicit command (not a Bundler plugin or a `post_install` hook)

bundler-skills is a regular gem that ships a plain executable (`bundle exec
skills`). Syncing happens only when you run that command — it hooks into nothing.

Two earlier designs were tried and rejected:

- **A Bundler plugin** that registered a `bundle skills` command via
  `Bundler::Plugin::API.command`. When `bundle update` bumped bundler-skills
  itself, Bundler re-registered the `skills` command while the previous
  registration was still in its plugin index, raising
  `Bundler::Plugin::Index::CommandConflict` — and it recurred on every
  subsequent `bundle` run until `bundler plugin uninstall`. This is unavoidable
  for any plugin that registers a command.
- **A RubyGems `post_install` hook** (`lib/rubygems_plugin.rb` +
  `Gem.post_install`). RubyGems auto-loads any `rubygems_plugin.rb` on the load
  path, so once bundler-skills is installed anywhere in a Ruby, its hook is
  loaded and evaluated for **every** `bundle install` of **every** project
  sharing that Ruby — a global side effect that is hard to scope cleanly.

Providing only a command removes both problems: there is no command
registration to conflict, and nothing runs unless the user invokes it. Wire it
into a git hook or a hook manager to run it automatically — see
[README.md](README.md) for consumer details.
