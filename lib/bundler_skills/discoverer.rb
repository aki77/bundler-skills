# frozen_string_literal: true

require_relative "discovered_skill"

module BundlerSkills
  # Finds skills bundled in the resolved dependency gems.
  #
  # This is the ONLY place that touches the Bundler spec API. The default
  # `specs` come from Bundler.load.specs, which reflects the current
  # environment's resolved gems (includes development/test groups unless
  # `without` excludes them). Each spec exposes full_gem_path / name / version
  # and works for rubygems, path and git sources alike.
  class Discoverer
    SKILL_FILE = "SKILL.md"

    def initialize(specs: nil, config: Config.new(Config::DEFAULTS), logger: nil)
      @specs = specs
      @config = config
      @logger = logger
    end

    # @return [Array<DiscoveredSkill>]
    def discover
      specs.flat_map { |spec| skills_in(spec) }.compact
    end

    private

    def specs
      @specs ||= Bundler.load.specs
    end

    def skills_in(spec)
      gem_path = spec.full_gem_path
      return [] unless gem_path && File.directory?(gem_path)

      pattern = @config.recursive? ? "skills/**/#{SKILL_FILE}" : "skills/*/#{SKILL_FILE}"
      Dir.glob(File.join(gem_path, pattern)).filter_map do |skill_md|
        skill_dir = File.dirname(skill_md)
        skill_name = File.basename(skill_dir)
        next unless @config.included?(spec.name, skill_name)

        DiscoveredSkill.new(
          gem_name: spec.name,
          skill_name: skill_name,
          source_path: File.expand_path(skill_dir)
        )
      end
    rescue StandardError => e
      warn_skip(spec, e)
      []
    end

    def warn_skip(spec, error)
      message = "[bundler-skills] skipped #{spec.name}: #{error.class}: #{error.message}"
      if @logger
        @logger.warn(message)
      elsif defined?(Bundler)
        Bundler.ui.warn(message)
      end
    end
  end
end
