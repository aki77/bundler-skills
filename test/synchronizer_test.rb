# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

# Drives Synchronizer end-to-end against fake specs in a tmpdir (no real
# bundle install — that path is covered by the bundle-install E2E in phase 8).
class SynchronizerTest < Minitest::Test
  FakeSpec = Struct.new(:name, :version, :full_gem_path)

  # Captures which summary channel was used: confirm (green, "something
  # changed") vs info (plain, "nothing to do").
  class CapturingLogger
    attr_reader :confirmed, :infos

    def initialize
      @confirmed = []
      @infos = []
    end

    def confirm(msg) = @confirmed << msg
    def info(msg) = @infos << msg
    def warn(msg) = nil
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

  def test_plan_discovers_without_touching_fs
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      result = BundlerSkills::Synchronizer.new(
        root: dir, config: BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS),
        logger: nil, specs: [spec]
      ).plan
      assert_equal 1, result.discovered.size
      assert_equal %w[claude], result.agents.map(&:key)
      refute File.exist?(File.join(dir, ".claude", "skills"))
    end
  end

  def test_summary_uses_confirm_when_links_created
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      logger = CapturingLogger.new
      BundlerSkills::Synchronizer.new(
        root: dir, config: BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS),
        logger: logger, specs: [spec]
      ).sync
      assert_equal 1, logger.confirmed.size
      assert_match(/1 linked, 0 relinked, 0 pruned/, logger.confirmed.first)
      # The created skill is listed with its source path so the user can
      # review the linked SKILL.md.
      detail = logger.infos.join("\n")
      assert_match(/created:/, detail)
      assert_match(%r{\.claude/skills/gem-rubocop--style {2}->.*style}, detail)
    end
  end

  def test_summary_uses_info_when_nothing_changed
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      sync(dir, [spec]) # first run creates the link
      logger = CapturingLogger.new
      BundlerSkills::Synchronizer.new(
        root: dir, config: BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS),
        logger: logger, specs: [spec]
      ).sync # second run keeps it -> nothing changed
      assert_empty logger.confirmed
      assert_equal 1, logger.infos.size
    end
  end

  def test_summary_lists_pruned_skills_by_name_only
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      sync(dir, [spec]) # create the link
      logger = CapturingLogger.new
      BundlerSkills::Synchronizer.new(
        root: dir, config: BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS),
        logger: logger, specs: [] # gem gone -> pruned
      ).sync
      detail = logger.infos.join("\n")
      assert_match(/pruned:/, detail)
      assert_match(%r{^\s+\.claude/skills/gem-rubocop--style$}, detail)
      # No source path arrow for pruned (skill already gone), and unused
      # category labels are omitted.
      refute_match(/created:/, detail)
      refute_match(/relinked:/, detail)
    end
  end

  def test_clean_removes_all_owned_links
    Dir.mktmpdir do |dir|
      marker(dir, ".claude")
      spec = fake_gem(dir, "rubocop", skills: %w[style])
      sync(dir, [spec])
      removed = BundlerSkills::Synchronizer.new(
        root: dir, config: BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS),
        logger: nil, specs: [spec]
      ).clean
      assert_equal ["gem-rubocop--style"], removed[".claude/skills"]
      refute File.exist?(File.join(dir, ".claude", "skills", "gem-rubocop--style"))
    end
  end
end
