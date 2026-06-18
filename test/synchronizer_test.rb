# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

# Drives Synchronizer end-to-end against fake specs in a tmpdir (no real
# bundle install — that path is covered by the bundle-install E2E in phase 8).
class SynchronizerTest < Minitest::Test
  FakeSpec = Struct.new(:name, :version, :full_gem_path)

  def fake_gem(root, name, skills:)
    path = File.join(root, "gems", name)
    skills.each do |s|
      dir = File.join(path, "skills", s)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "SKILL.md"), "# #{s}")
    end
    FakeSpec.new(name, "1.0.0", path)
  end

  def marker(root, name)
    FileUtils.mkdir_p(File.join(root, name))
  end

  def sync(root, specs, config: BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS))
    BundlerSkills::Synchronizer.new(root: root, config: config, logger: nil, specs: specs).sync
  end

  def links_for(result, subdir)
    result.links_by_dir[subdir]
  end

  def test_links_into_claude_skills_when_claude_marker_present
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = sync(dir, [spec])
      link = File.join(dir, ".claude", "skills", "gem-rubocop--style")
      assert File.symlink?(link)
      assert_equal ["gem-rubocop--style"], links_for(result, ".claude/skills").created
    end
  end

  def test_no_agent_detected_links_nothing
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = sync(dir, [spec])
      assert_empty result.agents
      assert_empty result.links_by_dir
      refute File.exist?(File.join(dir, ".claude"))
      refute File.exist?(File.join(dir, ".agents"))
    end
  end

  def test_links_shared_agents_dir_once_for_cursor_and_codex
    Dir.mktmpdir do |dir|
      marker(dir, ".cursor")
      File.write(File.join(dir, "AGENTS.md"), "x") # codex marker
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = sync(dir, [spec])
      # cursor + codex both map to .agents/skills -> deduped to one dir.
      assert_equal [".agents/skills"], result.links_by_dir.keys
      link = File.join(dir, ".agents", "skills", "gem-rubocop--style")
      assert File.symlink?(link)
    end
  end

  def test_links_both_dirs_for_claude_and_cursor
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      marker(dir, ".cursor")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = sync(dir, [spec])
      assert_equal [".claude/skills", ".agents/skills"], result.links_by_dir.keys
      assert File.symlink?(File.join(dir, ".claude", "skills", "gem-rubocop--style"))
      assert File.symlink?(File.join(dir, ".agents", "skills", "gem-rubocop--style"))
    end
  end

  def test_idempotent_across_two_syncs
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      sync(dir, [spec])
      result = sync(dir, [spec])
      assert_empty links_for(result, ".claude/skills").created
      assert_equal ["gem-rubocop--style"], links_for(result, ".claude/skills").kept
    end
  end

  def test_updates_gitignore_for_active_dirs
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = sync(dir, [spec])
      assert result.gitignore_changed
      content = File.read(File.join(dir, ".gitignore"))
      assert_includes content, ".claude/skills/gem-*"
      refute_includes content, ".agents/skills/gem-*" # cursor not present
    end
  end

  def test_no_gitignore_when_no_agent
    Dir.mktmpdir do |dir|
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = sync(dir, [spec])
      refute result.gitignore_changed
      refute File.exist?(File.join(dir, ".gitignore"))
    end
  end

  def test_prunes_when_gem_removed
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      sync(dir, [spec])
      result = sync(dir, []) # gem gone
      assert_equal ["gem-rubocop--style"], links_for(result, ".claude/skills").pruned
      refute File.exist?(File.join(dir, ".claude", "skills", "gem-rubocop--style"))
    end
  end
end
