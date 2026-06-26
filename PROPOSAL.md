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

## Why a RubyGems `post_install` hook (not a Bundler plugin)

bundler-skills ships as a regular gem with a `lib/rubygems_plugin.rb` that
registers a `Gem.post_install` hook. The hook **does** fire during
`bundle install` for each gem that is actually installed (only `Gem.done_installing`
is Bundler-skipped), so it is a reliable place to sync that gem's skills.

An earlier version was a Bundler plugin that registered a `bundle skills`
command via `Bundler::Plugin::API.command`. That had a fatal flaw: when
`bundle update` bumped bundler-skills itself, Bundler re-registered the `skills`
command while the previous registration was still in its plugin index, raising
`Bundler::Plugin::Index::CommandConflict` — and it recurred on every subsequent
`bundle` run until `bundler plugin uninstall`. This is unavoidable for any plugin
that registers a command. Becoming a regular gem removes the command registration
entirely (the manual command is now the plain executable `bundle exec skills`),
so the conflict cannot happen. See [README.md](README.md) for consumer details.
