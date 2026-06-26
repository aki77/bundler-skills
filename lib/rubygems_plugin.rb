# frozen_string_literal: true

# RubyGems loads this file automatically (it is on the require path and named
# by the rubygems_plugin convention) during `bundle install` / `gem install`.
# We register a post_install hook that syncs each freshly installed gem's
# skills. This replaces the old Bundler plugin (`command "skills"` caused a
# CommandConflict whenever the plugin updated itself).
require_relative "bundler_skills"
require_relative "bundler_skills/rubygems_hook"

Gem.post_install do |installer|
  BundlerSkills::RubygemsHook.install(installer)
end
