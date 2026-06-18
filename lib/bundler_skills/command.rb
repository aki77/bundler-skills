# frozen_string_literal: true

module BundlerSkills
  # `bundle skills [sync|list|clean] [--dry-run]`
  #
  # The manual entry point. Unlike the hook, it ignores the production/CI
  # disabling guard — running it is an explicit user action. It reuses the
  # same Synchronizer logic the hook uses.
  class Command < Bundler::Plugin::API
    command "skills"

    INIT_TEMPLATE = <<~YAML
      # bundler-skills.yml — all keys are optional
      #
      # enabled:                    # nil (auto) | false (off) | [development] (env list)
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

    def exec(_command_name, args)
      dry_run = !!args.delete("--dry-run")
      subcommand = args.shift || "sync"

      case subcommand
      when "sync" then run_sync(dry_run)
      when "list" then run_list
      when "clean" then run_clean(dry_run)
      when "init" then run_init
      when "help", "-h", "--help" then print_help
      else
        Bundler.ui.error("[bundler-skills] unknown subcommand: #{subcommand}")
        print_help
      end
    end

    private

    def synchronizer(dry_run: false)
      config = Config.load
      config = OverrideDryRun.new(config) if dry_run
      Synchronizer.new(config: config)
    end

    def run_sync(dry_run)
      synchronizer(dry_run: dry_run).sync
    end

    def run_list
      result = synchronizer.plan
      if result.discovered.empty?
        Bundler.ui.info("[bundler-skills] no skills found in dependency gems")
        return
      end

      agents = result.agents.map(&:key)
      Bundler.ui.info("[bundler-skills] #{result.discovered.size} skill(s) " \
                      "-> agents: #{agents.empty? ? '(none detected)' : agents.join(', ')}")
      result.discovered.sort_by(&:link_name).each do |skill|
        Bundler.ui.info("  #{skill.link_name}  ->  #{skill.source_path}")
      end
    end

    def run_init
      path = Bundler.root / Config::CONFIG_FILENAME
      if File.exist?(path)
        Bundler.ui.warn("[bundler-skills] #{Config::CONFIG_FILENAME} already exists")
        return
      end

      File.write(path, INIT_TEMPLATE)
      Bundler.ui.info("[bundler-skills] created #{Config::CONFIG_FILENAME}")
    end

    def run_clean(dry_run)
      removed = synchronizer(dry_run: dry_run).clean
      total = removed.values.sum(&:size)
      verb = dry_run ? "would remove" : "removed"
      Bundler.ui.info("[bundler-skills] #{verb} #{total} link(s)")
      removed.each do |subdir, names|
        names.each { |n| Bundler.ui.info("  #{subdir}/#{n}") }
      end
    end

    def print_help
      Bundler.ui.info(<<~HELP)
        Usage: bundle skills [SUBCOMMAND] [--dry-run]

          sync   (default) discover skills and (re)create symlinks
          list   show discovered skills and target agents (no changes)
          clean  remove all gem-*--* symlinks this plugin created
          init   create a bundler-skills.yml config file with defaults

        Options:
          --dry-run   show what would change without writing
      HELP
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
