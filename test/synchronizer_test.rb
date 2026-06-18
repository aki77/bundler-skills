# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

# Drives Synchronizer end-to-end against fake specs in a tmpdir (no real
# bundle install — that path is covered by the bundle-install E2E in phase 8).
class SynchronizerTest < Minitest::Test
  FakeSpec = Struct.new(:name, :version, :full_gem_path)

  def setup
    @logger = nil
  end

  def fake_gem(root, name, skills:)
    path = File.join(root, "gems", name)
    skills.each do |s|
      dir = File.join(path, "skills", s)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "SKILL.md"), "# #{s}")
    end
    FakeSpec.new(name, "1.0.0", path)
  end

  def sync(root, specs, config: BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS))
    BundlerSkills::Synchronizer.new(root: root, config: config, logger: nil, specs: specs).sync
  end

  def test_links_discovered_skills_into_claude_skills
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = sync(dir, [spec])
      link = File.join(dir, ".claude", "skills", "gem-rubocop--style")
      assert File.symlink?(link)
      assert_equal 1, result.discovered.size
      assert_equal ["gem-rubocop--style"], result.links.created
    end
  end

  def test_idempotent_across_two_syncs
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      sync(dir, [spec])
      result = sync(dir, [spec])
      assert_empty result.links.created
      assert_equal ["gem-rubocop--style"], result.links.kept
    end
  end

  def test_prunes_when_gem_removed
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      sync(dir, [spec])
      result = sync(dir, []) # gem gone
      assert_equal ["gem-rubocop--style"], result.links.pruned
      refute File.exist?(File.join(dir, ".claude", "skills", "gem-rubocop--style"))
    end
  end
end
