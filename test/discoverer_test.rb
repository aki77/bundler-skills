# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class DiscovererTest < Minitest::Test
  FakeSpec = Struct.new(:name, :version, :full_gem_path)

  def cfg(data = {})
    BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS.merge(data))
  end

  # Build a fake gem dir with the given skill subdirs (each gets a SKILL.md).
  def fake_gem(root, name, skills:, with_skill_md: skills)
    path = File.join(root, name)
    skills.each do |skill|
      dir = File.join(path, "skills", skill)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "SKILL.md"), "# #{skill}") if with_skill_md.include?(skill)
    end
    FakeSpec.new(name, "1.0.0", path)
  end

  def test_discovers_skills_with_skill_md
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rubocop", skills: %w[style lint])
      skills = BundlerSkills::Discoverer.new(specs: [spec], config: cfg).discover
      assert_equal %w[lint style], skills.map(&:skill_name).sort
      assert(skills.all? { |s| s.gem_name == "rubocop" })
    end
  end

  def test_link_name_uses_double_hyphen_boundary
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rails-html-sanitizer", skills: %w[escaping])
      skill = BundlerSkills::Discoverer.new(specs: [spec], config: cfg).discover.first
      assert_equal "gem-rails-html-sanitizer--escaping", skill.link_name
    end
  end

  def test_skips_dirs_without_skill_md
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "g", skills: %w[has_md no_md], with_skill_md: %w[has_md])
      skills = BundlerSkills::Discoverer.new(specs: [spec], config: cfg).discover
      assert_equal %w[has_md], skills.map(&:skill_name)
    end
  end

  def test_non_recursive_ignores_nested
    Dir.mktmpdir do |dir|
      path = File.join(dir, "g")
      nested = File.join(path, "skills", "group", "deep")
      FileUtils.mkdir_p(nested)
      File.write(File.join(nested, "SKILL.md"), "x")
      spec = FakeSpec.new("g", "1.0", path)
      skills = BundlerSkills::Discoverer.new(specs: [spec], config: cfg).discover
      assert_empty skills
    end
  end

  def test_recursive_finds_nested
    Dir.mktmpdir do |dir|
      path = File.join(dir, "g")
      nested = File.join(path, "skills", "group", "deep")
      FileUtils.mkdir_p(nested)
      File.write(File.join(nested, "SKILL.md"), "x")
      spec = FakeSpec.new("g", "1.0", path)
      skills = BundlerSkills::Discoverer.new(specs: [spec], config: cfg("recursive" => true)).discover
      assert_equal %w[deep], skills.map(&:skill_name)
    end
  end

  def test_applies_include_exclude
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      other = fake_gem(dir, "noisy", skills: %w[ad])
      skills = BundlerSkills::Discoverer.new(
        specs: [spec, other], config: cfg("exclude" => ["noisy"])
      ).discover
      assert_equal %w[rubocop], skills.map(&:gem_name)
    end
  end

  def test_missing_gem_path_is_skipped
    spec = FakeSpec.new("ghost", "1.0", "/nonexistent/path/xyz")
    skills = BundlerSkills::Discoverer.new(specs: [spec], config: cfg).discover
    assert_empty skills
  end
end
