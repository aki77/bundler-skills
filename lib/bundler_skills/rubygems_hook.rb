# frozen_string_literal: true

module BundlerSkills
  # Entry point for the RubyGems `Gem.post_install` hook (registered in
  # lib/rubygems_plugin.rb). Fires once per gem actually installed during a
  # `bundle install` / `bundle update`, and syncs THAT gem's skills only.
  #
  # Like the old Bundler hook, it holds no real logic: it guards on context and
  # the disable switch, then delegates to Synchronizer#sync_gem. Any error is
  # swallowed as a warning so it never aborts the user's install.
  module RubygemsHook
    module_function

    # @param installer [#spec] a Gem::Installer (or anything exposing #spec)
    def install(installer)
      spec = installer.spec
      return unless bundle_context?
      return if Disabling.disabled?

      Synchronizer.new(config: Config.load).sync_gem(spec)
    rescue StandardError => e
      warn("[bundler-skills] skipped #{safe_name(installer)}: #{e.class}: #{e.message}")
    end

    # Only act inside a `bundle install` for a project with a Gemfile. This
    # keeps a plain `gem install foo` (no project context) from creating
    # symlinks in whatever directory the user happens to be in.
    def bundle_context?
      return false unless defined?(Bundler)

      root = Bundler.root
      root.join("Gemfile").file? || root.join("gems.rb").file?
    rescue StandardError
      false
    end

    def safe_name(installer)
      installer.spec.name
    rescue StandardError
      "(unknown gem)"
    end

    def warn(message)
      if defined?(Bundler)
        Bundler.ui.warn(message)
      else
        Kernel.warn(message)
      end
    end
  end
end
