# frozen_string_literal: true

module BundlerSkills
  # Orchestrates discovery -> linking -> gitignore across the resolved agents.
  # Shared entry point for both the Hook (after-install-all) and the manual
  # `bundle skills` command.
  #
  # Phase 1 skeleton: just logs that it ran. Later phases wire in Discoverer,
  # AgentRegistry, Linker and GitignoreUpdater.
  class Synchronizer
    def initialize(root: Bundler.root, config: Config.load, logger: Bundler.ui)
      @root = root
      @config = config
      @logger = logger
    end

    def sync
      @logger.info("[bundler-skills] sync (skeleton — no skills linked yet)")
    end
  end
end
