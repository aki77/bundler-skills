# frozen_string_literal: true

module BundlerSkills
  # Registers the after-install-all hook.
  #
  # The hook itself holds no logic: it guards on Disabling (skip in
  # production/CI), then delegates to Synchronizer. Any error is logged as a
  # warning so it never aborts the user's `bundle install`.
  #
  # NOTE: the block argument of after-install-all is an Array<Bundler::Dependency>,
  # NOT specs. We intentionally ignore it and read Bundler.load.specs inside
  # the Synchronizer instead.
  module Hook
    module_function

    def register
      Bundler::Plugin.add_hook("after-install-all") do |_dependencies|
        call
      end
    end

    def call
      config = Config.load
      return if Disabling.disabled?(config: config)

      Synchronizer.new(config: config).sync
    rescue StandardError => e
      Bundler.ui.warn("[bundler-skills] skipped: #{e.class}: #{e.message}")
    end
  end
end
