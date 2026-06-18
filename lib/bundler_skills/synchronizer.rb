# frozen_string_literal: true

module BundlerSkills
  # Orchestrates discovery -> linking across the resolved agents. Shared entry
  # point for both the Hook (after-install-all) and the manual `bundle skills`
  # command.
  #
  # Discovery runs once (agent-independent); linking runs once per distinct
  # output directory (.claude/skills and/or .agents/skills). Phase 4 adds the
  # .gitignore update.
  class Synchronizer
    Result = Struct.new(:discovered, :agents, :links_by_dir, :gitignore_changed, keyword_init: true)

    def initialize(root: Bundler.root, config: Config.load, logger: Bundler.ui, specs: nil)
      @root = root
      @config = config
      @logger = logger
      @specs = specs
    end

    def sync
      skills = Discoverer.new(specs: @specs, config: @config, logger: @logger).discover
      agents = AgentRegistry.resolve(@root, @config)
      subdirs = AgentRegistry.output_subdirs(agents)

      links_by_dir = subdirs.to_h do |subdir|
        skills_dir = File.join(@root.to_s, subdir)
        [subdir, Linker.new(skills_dir: skills_dir, config: @config, logger: @logger).link(skills)]
      end

      gitignore_changed = update_gitignore(subdirs)

      log_summary(skills, agents, links_by_dir)
      Result.new(
        discovered: skills, agents: agents,
        links_by_dir: links_by_dir, gitignore_changed: gitignore_changed
      )
    end

    # Discover skills and the agents/dirs that would receive them, without
    # touching the filesystem. Used by `bundle skills list`.
    def plan
      skills = Discoverer.new(specs: @specs, config: @config, logger: @logger).discover
      agents = AgentRegistry.resolve(@root, @config)
      Result.new(
        discovered: skills, agents: agents,
        links_by_dir: {}, gitignore_changed: false
      )
    end

    # Remove every gem-*--* symlink we own across all known output dirs.
    # Used by `bundle skills clean`. Returns { subdir => [removed names] }.
    def clean
      AgentRegistry.all.map(&:skills_subdir).uniq.to_h do |subdir|
        skills_dir = File.join(@root.to_s, subdir)
        linker = Linker.new(skills_dir: skills_dir, config: @config, logger: @logger)
        [subdir, linker.clean_all]
      end
    end

    private

    def update_gitignore(subdirs)
      return false unless @config.gitignore?
      return false if subdirs.empty?

      patterns = subdirs.map { |subdir| "#{subdir}/#{DiscoveredSkill::LINK_PREFIX}*" }
      GitignoreUpdater.new(
        gitignore_path: File.join(@root.to_s, ".gitignore"),
        dry_run: @config.dry_run?
      ).ensure_patterns(patterns)
    end

    def log_summary(skills, agents, links_by_dir)
      return unless @logger

      if agents.empty?
        @logger.info(
          "[bundler-skills] #{skills.size} skill(s) discovered but no agent detected " \
          "(.claude/.cursor/.codex/AGENTS.md/.github) — nothing linked"
        )
        return
      end

      created = links_by_dir.values.sum { |r| r.created.size }
      pruned = links_by_dir.values.sum { |r| r.pruned.size }
      @logger.info(
        "[bundler-skills] #{skills.size} skill(s) discovered, " \
        "#{created} linked, #{pruned} pruned across #{links_by_dir.size} dir(s) " \
        "(agents: #{agents.map(&:key).join(', ')})"
      )
    end
  end
end
