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

## Why a Bundler plugin (not RubyGems hooks)

RubyGems' `post_install` hooks don't fire during `bundle install`, so a Bundler
plugin using the `after-install-all` hook is the reliable place to do this. See
[README.md](README.md) for the consumer-side details.
