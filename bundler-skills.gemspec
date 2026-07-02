# frozen_string_literal: true

require_relative "lib/bundler_skills/version"

Gem::Specification.new do |spec|
  spec.name = "bundler-skills"
  spec.version = BundlerSkills::VERSION
  spec.authors = ["aki77"]
  spec.email = ["aki77@users.noreply.github.com"]

  spec.summary = "Symlink AI agent skills bundled in your gems via the bundle exec skills command."
  spec.description = "A gem that discovers skills/ directories bundled in your dependency " \
                     "gems and symlinks them into your project's agent skill directories " \
                     "(.claude/skills, .agents/skills) via the `bundle exec skills` command. " \
                     "The Ruby/Bundler counterpart of antfu/skills-npm."
  spec.homepage = "https://github.com/aki77/bundler-skills"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # exe/skills is the `bundle exec skills` command.
  spec.files = Dir[
    "lib/**/*.rb",
    "exe/**/*",
    "README.md",
    "PROPOSAL.md",
    "CHANGELOG.md",
    "LICENSE*"
  ]
  spec.bindir = "exe"
  spec.executables = ["skills"]
  spec.require_paths = ["lib"]
end
