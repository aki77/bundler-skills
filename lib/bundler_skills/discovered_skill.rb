# frozen_string_literal: true

module BundlerSkills
  # One skill found inside a dependency gem.
  #
  # source_path : absolute path to the directory containing SKILL.md
  # link_name   : symlink basename, "gem-<gem>--<skill>" (double-hyphen boundary
  #               so a gem name containing single hyphens stays unambiguous)
  class DiscoveredSkill
    LINK_PREFIX = "gem-"
    BOUNDARY = "--"

    attr_reader :gem_name, :skill_name, :source_path

    def initialize(gem_name:, skill_name:, source_path:)
      @gem_name = gem_name
      @skill_name = skill_name
      @source_path = source_path
    end

    def link_name
      "#{LINK_PREFIX}#{gem_name}#{BOUNDARY}#{skill_name}"
    end

    def ==(other)
      other.is_a?(DiscoveredSkill) &&
        gem_name == other.gem_name &&
        skill_name == other.skill_name &&
        source_path == other.source_path
    end
    alias eql? ==

    def hash
      [gem_name, skill_name, source_path].hash
    end
  end
end
