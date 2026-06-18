# frozen_string_literal: true

module BundlerSkills
  # Orchestrates discovery -> linking. Shared entry point for both the Hook
  # (after-install-all) and the manual `bundle skills` command.
  #
  # Phase 2: single output directory (.claude/skills). Phase 3 generalizes this
  # to the resolved agents via AgentRegistry; Phase 4 adds .gitignore updates.
  class Synchronizer
    CLAUDE_SKILLS_SUBDIR = ".claude/skills"

    Result = Struct.new(:discovered, :links, keyword_init: true)

    def initialize(root: Bundler.root, config: Config.load, logger: Bundler.ui, specs: nil)
      @root = root
      @config = config
      @logger = logger
      @specs = specs
    end

    def sync
      skills = Discoverer.new(specs: @specs, config: @config, logger: @logger).discover
      skills_dir = File.join(@root.to_s, CLAUDE_SKILLS_SUBDIR)
      link_result = Linker.new(skills_dir: skills_dir, config: @config, logger: @logger).link(skills)
      log_summary(skills, link_result)
      Result.new(discovered: skills, links: link_result)
    end

    private

    def log_summary(skills, link_result)
      return unless @logger

      created = link_result.created.size
      pruned = link_result.pruned.size
      @logger.info(
        "[bundler-skills] #{skills.size} skill(s) discovered, " \
        "#{created} linked, #{pruned} pruned"
      )
    end
  end
end
