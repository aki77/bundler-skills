# frozen_string_literal: true

require_relative "lib/bundler_skills/version"

Gem::Specification.new do |spec|
  spec.name = "bundler-skills"
  spec.version = BundlerSkills::VERSION
  spec.authors = ["aki77"]
  spec.email = ["aki77@users.noreply.github.com"]

  spec.summary = "Auto-symlink AI agent skills bundled in your gems after bundle install."
  spec.description = "A gem that discovers skills/ directories bundled in your dependency " \
                     "gems and symlinks them into your project's agent skill directories " \
                     "(.claude/skills, .agents/skills) on bundle install, via a RubyGems " \
                     "post_install hook. The Ruby/Bundler counterpart of antfu/skills-npm."
  spec.homepage = "https://github.com/aki77/bundler-skills"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # lib/rubygems_plugin.rb (matched by lib/**/*.rb) is the RubyGems plugin entry
  # point; exe/bundler-skills is the manual `bundler-skills` command.
  spec.files = Dir[
    "lib/**/*.rb",
    "exe/**/*",
    "README.md",
    "PROPOSAL.md",
    "CHANGELOG.md",
    "LICENSE*"
  ]
  spec.bindir = "exe"
  spec.executables = ["bundler-skills"]
  spec.require_paths = ["lib"]
end
