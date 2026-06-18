# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class AgentRegistryTest < Minitest::Test
  def cfg(agents: nil)
    data = BundlerSkills::Config::DEFAULTS.merge("agents" => agents)
    BundlerSkills::Config.new(data)
  end

  def with_markers(*markers)
    Dir.mktmpdir do |dir|
      markers.each do |m|
        path = File.join(dir, m)
        if m.end_with?(".md")
          File.write(path, "x")
        else
          FileUtils.mkdir_p(path)
        end
      end
      yield dir
    end
  end

  def keys(agents)
    agents.map(&:key)
  end

  def test_detect_claude
    with_markers(".claude") do |dir|
      assert_equal %w[claude], keys(BundlerSkills::AgentRegistry.detect(dir))
    end
  end

  def test_detect_codex_via_agents_md
    with_markers("AGENTS.md") do |dir|
      assert_equal %w[codex], keys(BundlerSkills::AgentRegistry.detect(dir))
    end
  end

  def test_detect_multiple
    with_markers(".claude", ".cursor") do |dir|
      assert_equal %w[claude cursor], keys(BundlerSkills::AgentRegistry.detect(dir))
    end
  end

  def test_detect_none
    Dir.mktmpdir do |dir|
      assert_empty BundlerSkills::AgentRegistry.detect(dir)
    end
  end

  def test_output_subdirs_dedups_agents_skills
    agents = %w[cursor codex copilot].map { |k| BundlerSkills::AgentRegistry.find(k) }
    assert_equal [".agents/skills"], BundlerSkills::AgentRegistry.output_subdirs(agents)
  end

  def test_output_subdirs_claude_and_shared
    agents = %w[claude cursor].map { |k| BundlerSkills::AgentRegistry.find(k) }
    assert_equal [".claude/skills", ".agents/skills"], BundlerSkills::AgentRegistry.output_subdirs(agents)
  end

  def test_resolve_auto_detect_when_agents_nil
    with_markers(".cursor") do |dir|
      agents = BundlerSkills::AgentRegistry.resolve(dir, cfg(agents: nil))
      assert_equal %w[cursor], keys(agents)
    end
  end

  def test_resolve_explicit_list_overrides_detection
    with_markers(".cursor") do |dir|
      agents = BundlerSkills::AgentRegistry.resolve(dir, cfg(agents: %w[claude]))
      assert_equal %w[claude], keys(agents)
    end
  end

  def test_resolve_wildcard
    Dir.mktmpdir do |dir|
      agents = BundlerSkills::AgentRegistry.resolve(dir, cfg(agents: %w[*]))
      assert_equal %w[claude cursor codex copilot], keys(agents)
    end
  end

  def test_resolve_ignores_unknown_keys
    Dir.mktmpdir do |dir|
      agents = BundlerSkills::AgentRegistry.resolve(dir, cfg(agents: %w[claude bogus]))
      assert_equal %w[claude], keys(agents)
    end
  end
end
