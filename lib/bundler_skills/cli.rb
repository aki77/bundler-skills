# frozen_string_literal: true

require "optparse"

module BundlerSkills
  # `bundle exec skills [sync|list|clean|init] [--dry-run]`
  #
  # The manual entry point (a plain executable, not a Bundler plugin command).
  # Unlike the post_install hook it ignores the disable switch — running it is an
  # explicit user action — and it reuses the same Synchronizer logic.
  class CLI
    INIT_TEMPLATE = <<~YAML
      # bundler-skills.yml — all keys are optional
      #
      # agents:                     # omit = auto-detect; or list: [claude, cursor]; or "*"
      #   - claude
      #   - cursor
      # gitignore: true             # manage .gitignore (default true)
      # cleanup: true               # prune stale gem-*--* links when a gem is removed (default true)
      # recursive: false            # also scan skills/**/SKILL.md (default false)
      # include:                    # only these gems (empty = all). fnmatch on "gem" or "gem/skill"
      #   - rubocop
      #   - "rails-*"
      # exclude:                    # exclude these (wins over include)
      #   - some-noisy-gem
    YAML

    USAGE = <<~HELP
      Usage: bundle exec skills [SUBCOMMAND] [--dry-run]

        sync   (default) discover skills and (re)create symlinks
        list   show discovered skills and target agents (no changes)
        clean  remove all gem-*--* symlinks this gem created
        init   create a bundler-skills.yml config file with defaults

      Options:
        --dry-run   show what would change without writing
        -h, --help  show this help
    HELP

    def initialize(logger: StdoutLogger.new)
      @logger = logger
    end

    # @param argv [Array<String>]
    # @return [Integer] process exit status
    def run(argv)
      args = argv.dup
      opts = { dry_run: false }
      parser = OptionParser.new do |o|
        o.on("--dry-run") { opts[:dry_run] = true }
        o.on("-h", "--help") { @logger.info(USAGE); return 0 }
      end
      parser.order!(args)

      subcommand = args.shift || "sync"
      case subcommand
      when "sync" then run_sync(opts[:dry_run])
      when "list" then run_list
      when "clean" then run_clean(opts[:dry_run])
      when "init" then run_init
      when "help" then @logger.info(USAGE)
      else
        @logger.error("[bundler-skills] unknown subcommand: #{subcommand}")
        @logger.info(USAGE)
        return 1
      end
      0
    rescue OptionParser::ParseError => e
      @logger.error("[bundler-skills] #{e.message}")
      @logger.info(USAGE)
      1
    end

    private

    def synchronizer(dry_run: false)
      config = Config.load
      config = OverrideDryRun.new(config) if dry_run
      Synchronizer.new(config: config, logger: @logger)
    end

    def run_sync(dry_run)
      synchronizer(dry_run: dry_run).sync
    end

    def run_list
      result = synchronizer.plan
      if result.discovered.empty?
        @logger.info("[bundler-skills] no skills found in dependency gems")
        return
      end

      agents = result.agents.map(&:key)
      @logger.info("[bundler-skills] #{result.discovered.size} skill(s) " \
                   "-> agents: #{agents.empty? ? '(none detected)' : agents.join(', ')}")
      result.discovered.sort_by(&:link_name).each do |skill|
        @logger.info("  #{skill.link_name}  ->  #{skill.source_path}")
      end
    end

    def run_init
      path = File.join(Bundler.root.to_s, Config::CONFIG_FILENAME)
      if File.exist?(path)
        @logger.warn("[bundler-skills] #{Config::CONFIG_FILENAME} already exists")
        return
      end

      File.write(path, INIT_TEMPLATE)
      @logger.info("[bundler-skills] created #{Config::CONFIG_FILENAME}")
    end

    def run_clean(dry_run)
      removed = synchronizer(dry_run: dry_run).clean
      total = removed.values.sum(&:size)
      verb = dry_run ? "would remove" : "removed"
      @logger.info("[bundler-skills] #{verb} #{total} link(s)")
      removed.each do |subdir, names|
        names.each { |n| @logger.info("  #{subdir}/#{n}") }
      end
    end

    # Minimal logger matching the subset of Bundler.ui that Synchronizer/Linker
    # use (info/warn/error/confirm), writing to stdout/stderr.
    class StdoutLogger
      def info(message)    = $stdout.puts(message)
      def confirm(message) = $stdout.puts(message)
      def warn(message)    = $stderr.puts(message)
      def error(message)   = $stderr.puts(message)
    end

    # Wraps a Config to force dry_run? true without mutating the original.
    class OverrideDryRun
      def initialize(config)
        @config = config
      end

      def dry_run?
        true
      end

      def respond_to_missing?(name, include_private = false)
        @config.respond_to?(name, include_private) || super
      end

      def method_missing(name, *args, &block)
        @config.send(name, *args, &block)
      end
    end
  end
end
