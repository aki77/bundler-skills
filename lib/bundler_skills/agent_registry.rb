# frozen_string_literal: true

module BundlerSkills
  # Knows where each supported agent reads project-level skills and how to
  # detect that the agent is in use. Dependency-free: a small internal table,
  # the single place to edit when an agent's convention changes.
  #
  # Output dirs collapse to two in practice:
  #   .claude/skills  — Claude Code only (does not read .agents/skills yet)
  #   .agents/skills  — cross-tool standard, shared by Cursor / Codex / Copilot
  module AgentRegistry
    # key          : config name (`agents:` entries match this)
    # skills_subdir: output directory relative to the project root
    # markers       : any of these existing means "this agent is in use"
    Agent = Struct.new(:key, :skills_subdir, :markers, keyword_init: true)

    ALL = [
      Agent.new(key: "claude",  skills_subdir: ".claude/skills",  markers: [".claude"]),
      Agent.new(key: "cursor",  skills_subdir: ".agents/skills",  markers: [".cursor"]),
      Agent.new(key: "codex",   skills_subdir: ".agents/skills",  markers: [".codex", "AGENTS.md"]),
      Agent.new(key: "copilot", skills_subdir: ".agents/skills",  markers: [".github"])
    ].freeze

    module_function

    def all
      ALL
    end

    def find(key)
      ALL.find { |a| a.key == key.to_s }
    end

    # Agents whose marker exists under root.
    def detect(root)
      ALL.select { |agent| present?(root, agent) }
    end

    # Resolve the agents to target:
    #   config.agents nil      -> auto-detect by markers
    #   config.agents ["*"]    -> all agents
    #   config.agents [keys..] -> those keys (unknown keys ignored)
    def resolve(root, config)
      requested = config.agents
      return detect(root) if requested.nil? || requested.empty?

      keys = Array(requested).map(&:to_s)
      return all if keys.include?("*")

      keys.filter_map { |key| find(key) }
    end

    # Distinct output subdirs for the given agents, preserving order.
    def output_subdirs(agents)
      agents.map(&:skills_subdir).uniq
    end

    def present?(root, agent)
      agent.markers.any? { |m| File.exist?(File.join(root.to_s, m)) }
    end
  end
end
