# frozen_string_literal: true

require_relative "lib/bundler_skills/version"

Gem::Specification.new do |spec|
  spec.name = "bundler-skills"
  spec.version = BundlerSkills::VERSION
  spec.authors = ["aki77"]
  spec.email = ["akira@sonicgarden.jp"]

  spec.summary = "Auto-symlink AI agent skills bundled in your gems after bundle install."
  spec.description = "A Bundler plugin that discovers skills/ directories bundled in your " \
                     "dependency gems and symlinks them into your project's agent skill " \
                     "directories (.claude/skills, .agents/skills) on bundle install. " \
                     "The Ruby/Bundler counterpart of antfu/skills-npm."
  spec.homepage = "https://github.com/aki77/bundler-skills"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["rubygems_mfa_required"] = "true"

  # plugins.rb MUST be packaged for Bundler to recognize this as a plugin.
  spec.files = Dir[
    "plugins.rb",
    "lib/**/*.rb",
    "README.md",
    "PROPOSAL.md",
    "LICENSE*"
  ]
  spec.require_paths = ["lib"]
end
