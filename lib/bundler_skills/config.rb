# frozen_string_literal: true

module BundlerSkills
  # Loads bundler-skills.yml and merges it with defaults.
  #
  # The file is optional: a missing file yields an all-defaults Config.
  # Supported keys:
  #   agents     nil(auto-detect) | "*" | [keys] | "key"
  #   gitignore  bool (default true)
  #   cleanup    bool (default true) — prune stale gem-*--* links
  #   recursive  bool (default false) — scan skills/**/SKILL.md
  #   include    [patterns]  — fnmatch on gem name or "gem/skill"
  #   exclude    [patterns]  — same, wins over include
  #   dry_run / force  bool
  class Config
    CONFIG_FILENAME = "bundler-skills.yml"

    DEFAULTS = {
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

    # nil (auto-detect) | Array<String>. A bare string key is wrapped so
    # `agents: claude` works as well as a YAML list.
    def agents
      value = @data["agents"]
      return nil if value.nil?

      Array(value).map(&:to_s)
    end

    def gitignore?
      @data["gitignore"] != false
    end

    def cleanup?
      @data["cleanup"] != false
    end

    def recursive?
      @data["recursive"] == true
    end

    def dry_run?
      @data["dry_run"] == true
    end

    def force?
      @data["force"] == true
    end

    def include_patterns
      Array(@data["include"]).map(&:to_s)
    end

    def exclude_patterns
      Array(@data["exclude"]).map(&:to_s)
    end

    # include/exclude are matched against the gem name (and "gem/skill") using
    # File.fnmatch wildcards. Empty include = allow all; exclude wins.
    def included?(gem_name, skill_name)
      return false if matches_any?(exclude_patterns, gem_name, skill_name)
      return true if include_patterns.empty?

      matches_any?(include_patterns, gem_name, skill_name)
    end

    private

    def matches_any?(patterns, gem_name, skill_name)
      candidates = [gem_name, "#{gem_name}/#{skill_name}"]
      patterns.any? do |pattern|
        candidates.any? { |c| File.fnmatch?(pattern, c, File::FNM_EXTGLOB) }
      end
    end
  end
end
