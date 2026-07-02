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
        linker = Linker.new(skills_dir: skills_dir, config: @config, logger: @logger)
        [subdir, linker.link(skills, prune_scope: :all)]
      end

      gitignore_changed = update_gitignore(subdirs, skills)

      log_summary(skills, agents, links_by_dir)
      Result.new(
        discovered: skills, agents: agents,
        links_by_dir: links_by_dir, gitignore_changed: gitignore_changed
      )
    end

    # Sync the skills of a SINGLE gem (used by the RubyGems post_install hook).
    #
    # Only links belonging to this gem (gem-<name>--*) are added/updated, and
    # only this gem's stale links are pruned — every other gem's links are left
    # untouched. So when a gem's new version drops or renames a skill, its old
    # link is removed, but unrelated gems are never disturbed.
    #
    # @param spec [#name, #full_gem_path] a Gem::Specification (or compatible)
    def sync_gem(spec)
      skills = Discoverer.new(specs: [spec], config: @config, logger: @logger).discover
      agents = AgentRegistry.resolve(@root, @config)
      subdirs = AgentRegistry.output_subdirs(agents)
      scope = ["#{DiscoveredSkill::LINK_PREFIX}#{spec.name}#{DiscoveredSkill::BOUNDARY}"]

      links_by_dir = subdirs.to_h do |subdir|
        skills_dir = File.join(@root.to_s, subdir)
        linker = Linker.new(skills_dir: skills_dir, config: @config, logger: @logger)
        [subdir, linker.link(skills, prune_scope: scope)]
      end

      gitignore_changed = update_gitignore(subdirs, skills)

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

    def update_gitignore(subdirs, skills)
      return false unless @config.gitignore?
      # Nothing to link (no agent dir, or no discovered skills) -> don't write
      # the managed block. This is the sole guard on the `bundler-skills sync`
      # (CLI) path, which has no opt-in gate: it keeps an empty managed block
      # out of a project whose gems ship no skills.
      return false if subdirs.empty? || skills.empty?

      patterns = subdirs.map { |subdir| "#{subdir}/#{DiscoveredSkill::LINK_PREFIX}*" }
      GitignoreUpdater.new(
        gitignore_path: File.join(@root.to_s, ".gitignore"),
        dry_run: @config.dry_run?
      ).ensure_patterns(patterns)
    end

    def log_summary(skills, agents, links_by_dir)
      return unless @logger

      # Nothing discovered and nothing changed -> stay silent. The post_install
      # hook fires for EVERY installed gem, most of which ship no skills;
      # emitting a "0 skill(s) discovered, 0 linked ..." line for each is noise.
      changed = links_by_dir.values.any?(&:changed?)
      return if skills.empty? && !changed

      if agents.empty?
        @logger.info(
          "[bundler-skills] #{skills.size} skill(s) discovered but no agent detected " \
          "(.claude/.cursor/.codex/AGENTS.md/.github) — nothing linked"
        )
        return
      end

      created = links_by_dir.values.sum { |r| r.created.size }
      relinked = links_by_dir.values.sum { |r| r.relinked.size }
      pruned = links_by_dir.values.sum { |r| r.pruned.size }

      message =
        "[bundler-skills] #{skills.size} skill(s) discovered, " \
        "#{created} linked, #{relinked} relinked, #{pruned} pruned " \
        "across #{links_by_dir.size} dir(s) (agents: #{agents.map(&:key).join(', ')})"

      # Make a run that actually changed something stand out (green) so it is
      # noticed amid bundle's output; an unchanged run stays plain.
      if changed
        @logger.confirm(message)
        # List the skills that changed so the user can review the (third-party)
        # SKILL.md contents now linked into their project. created/relinked are
        # in the discovery set so we can show their source path; pruned skills
        # are already gone, so we show the name only.
        log_changed_skills(skills, links_by_dir)
      else
        @logger.info(message)
      end
    end

    def log_changed_skills(skills, links_by_dir)
      source_by_link = skills.to_h { |s| [s.link_name, s.source_path] }

      %i[created relinked pruned].each do |kind|
        entries = links_by_dir.flat_map do |subdir, result|
          result.public_send(kind).map { |name| [File.join(subdir, name), source_by_link[name]] }
        end
        next if entries.empty?

        @logger.info("  #{kind}:")
        entries.each do |path, source|
          @logger.info(source ? "    #{path}  ->  #{source}" : "    #{path}")
        end
      end
    end
  end
end
