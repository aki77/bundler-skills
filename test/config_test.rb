# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ConfigTest < Minitest::Test
  def cfg(data = {})
    BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS.merge(data))
  end

  def test_defaults
    c = cfg
    assert_nil c.enabled
    assert_nil c.agents
    assert c.gitignore?
    assert c.cleanup?
    refute c.recursive?
    refute c.dry_run?
    refute c.force?
  end

  def test_boolean_flags_off
    c = cfg("gitignore" => false, "cleanup" => false, "recursive" => true, "force" => true)
    refute c.gitignore?
    refute c.cleanup?
    assert c.recursive?
    assert c.force?
  end

  def test_included_allows_all_when_no_include
    assert cfg.included?("rubocop", "style")
  end

  def test_exclude_wins
    c = cfg("exclude" => ["rubocop"])
    refute c.included?("rubocop", "style")
  end

  def test_include_filters
    c = cfg("include" => ["rubocop"])
    assert c.included?("rubocop", "style")
    refute c.included?("rails", "helpers")
  end

  def test_include_wildcard
    c = cfg("include" => ["rails-*"])
    assert c.included?("rails-html-sanitizer", "escaping")
    refute c.included?("pundit", "policies")
  end

  def test_include_gem_slash_skill
    c = cfg("include" => ["rubocop/style"])
    assert c.included?("rubocop", "style")
    refute c.included?("rubocop", "lint")
  end

  def test_exclude_wildcard_beats_include
    c = cfg("include" => ["rails-*"], "exclude" => ["rails-html-*"])
    refute c.included?("rails-html-sanitizer", "escaping")
    assert c.included?("rails-controller", "foo")
  end

  def test_load_missing_file_returns_defaults
    Dir.mktmpdir do |dir|
      c = BundlerSkills::Config.load(root: dir)
      assert_nil c.enabled
      assert c.gitignore?
    end
  end

  def test_load_reads_yaml
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "bundler-skills.yml"), <<~YAML)
        gitignore: false
        include:
          - rubocop
      YAML
      c = BundlerSkills::Config.load(root: dir)
      refute c.gitignore?
      assert_equal ["rubocop"], c.include_patterns
    end
  end
end
