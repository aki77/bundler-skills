# frozen_string_literal: true

module BundlerSkills
  # Loads bundler-skills.yml and merges it with defaults.
  #
  # Phase 1 skeleton: only the keys needed by Disabling are wired up. Later
  # phases fill in agents / include / exclude / cleanup / recursive etc.
  class Config
    CONFIG_FILENAME = "bundler-skills.yml"

    DEFAULTS = {
      "enabled" => nil,
      "agents" => nil,
      "gitignore" => true,
      "cleanup" => true,
      "recursive" => false,
      "dry_run" => false,
      "force" => false,
      "include" => [],
      "exclude" => []
    }.freeze

    def self.load(root: Bundler.root)
      path = File.join(root.to_s, CONFIG_FILENAME)
      data = read_yaml(path)
      new(DEFAULTS.merge(data))
    end

    def self.read_yaml(path)
      return {} unless File.file?(path)

      require "yaml"
      loaded = YAML.safe_load_file(path)
      loaded.is_a?(Hash) ? loaded : {}
    rescue StandardError => e
      Bundler.ui.warn("[bundler-skills] failed to read #{path}: #{e.message}") if defined?(Bundler)
      {}
    end

    def initialize(data)
      @data = data
    end

    def enabled
      @data["enabled"]
    end
  end
end
