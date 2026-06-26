# frozen_string_literal: true

require "fileutils"

module BundlerSkills
  # Creates idempotent absolute symlinks for discovered skills into a single
  # output directory, and prunes stale ones we previously created.
  #
  # Pure filesystem operations — no Bundler dependency, so it is fully unit
  # testable against a tmpdir. One Linker instance == one output directory
  # (e.g. .claude/skills or .agents/skills).
  class Linker
    STALE_GLOB = "#{DiscoveredSkill::LINK_PREFIX}*#{DiscoveredSkill::BOUNDARY}*"

    class Result
      attr_reader :created, :kept, :relinked, :skipped, :pruned

      def initialize
        @created = []
        @kept = []
        @relinked = []
        @skipped = []
        @pruned = []
      end

      # Did this run actually mutate the filesystem? kept/skipped are no-ops.
      def changed?
        created.any? || relinked.any? || pruned.any?
      end
    end

    def initialize(skills_dir:, config: Config.new(Config::DEFAULTS), logger: nil)
      @skills_dir = skills_dir
      @config = config
      @logger = logger
    end

    # @param skills [Array<DiscoveredSkill>]
    # @param prune_scope [Symbol, Array<String>, nil] which stale links to prune:
    #   :all (default)         -> every gem-*--* link we own (full sync)
    #   [prefix, ...]          -> only links whose basename starts with one of the
    #                             given prefixes, e.g. "gem-<name>--" (single-gem sync)
    #   nil                    -> prune nothing
    #   Pruning still honors @config.cleanup? — when cleanup is off nothing is pruned.
    # @return [Result]
    def link(skills, prune_scope: :all)
      result = Result.new
      link_names = skills.map(&:link_name)

      ensure_dir
      skills.each { |skill| link_one(skill, result) }
      prune_stale(link_names, result, prune_scope) if @config.cleanup? && prune_scope
      result
    end

    # Remove every gem-*--* symlink we own (for `bundle skills clean`).
    # @return [Array<String>] removed link names
    def clean_all
      removed = []
      Dir.glob(File.join(@skills_dir, STALE_GLOB)).each do |path|
        next unless File.symlink?(path)

        remove(path)
        removed << File.basename(path)
      end
      removed
    end

    private

    def ensure_dir
      return if @config.dry_run?

      FileUtils.mkdir_p(@skills_dir)
    end

    def link_one(skill, result)
      link_path = File.join(@skills_dir, skill.link_name)
      target = skill.source_path

      if File.symlink?(link_path)
        if File.readlink(link_path) == target
          result.kept << skill.link_name
        else
          replace_symlink(link_path, target)
          result.relinked << skill.link_name
        end
      elsif File.exist?(link_path)
        # A real file/dir the user created — never clobber it (unless force).
        if @config.force?
          remove(link_path)
          create_symlink(link_path, target)
          result.relinked << skill.link_name
        else
          warn("refusing to overwrite non-symlink #{link_path}")
          result.skipped << skill.link_name
        end
      else
        create_symlink(link_path, target)
        result.created << skill.link_name
      end
    end

    # Remove gem-*--* symlinks we own that are no longer in the discovery set.
    # Real directories, other prefixes, and unmanaged symlinks are left alone.
    # When +scope+ is an array of prefixes, only links whose basename starts with
    # one of them are considered (so a single-gem sync never touches other gems).
    def prune_stale(valid_link_names, result, scope = :all)
      Dir.glob(File.join(@skills_dir, STALE_GLOB)).each do |path|
        name = File.basename(path)
        next if valid_link_names.include?(name)
        next unless in_scope?(name, scope)
        next unless File.symlink?(path) # only prune our own symlinks

        remove(path)
        result.pruned << name
      end
    end

    def in_scope?(name, scope)
      return true if scope == :all

      Array(scope).any? { |prefix| name.start_with?(prefix) }
    end

    def replace_symlink(link_path, target)
      remove(link_path)
      create_symlink(link_path, target)
    end

    def create_symlink(link_path, target)
      return if @config.dry_run?

      File.symlink(target, link_path)
    end

    def remove(path)
      return if @config.dry_run?

      if File.symlink?(path)
        File.delete(path)
      else
        FileUtils.remove_entry(path)
      end
    end

    def warn(message)
      full = "[bundler-skills] #{message}"
      if @logger
        @logger.warn(full)
      elsif defined?(Bundler)
        Bundler.ui.warn(full)
      end
    end
  end
end
