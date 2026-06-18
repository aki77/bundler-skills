# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class GitignoreUpdaterTest < Minitest::Test
  PATTERNS = [".claude/skills/gem-*", ".agents/skills/gem-*"].freeze

  def updater(path, dry_run: false)
    BundlerSkills::GitignoreUpdater.new(gitignore_path: path, dry_run: dry_run)
  end

  def test_creates_file_when_absent
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitignore")
      changed = updater(path).ensure_patterns(PATTERNS)
      assert changed
      content = File.read(path)
      assert_includes content, ".claude/skills/gem-*"
      assert_includes content, ".agents/skills/gem-*"
      assert_includes content, BundlerSkills::GitignoreUpdater::BEGIN_MARKER
    end
  end

  def test_idempotent_no_change_on_second_run
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitignore")
      updater(path).ensure_patterns(PATTERNS)
      before = File.read(path)
      changed = updater(path).ensure_patterns(PATTERNS)
      refute changed
      assert_equal before, File.read(path)
    end
  end

  def test_appends_to_existing_content_preserving_it
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitignore")
      File.write(path, "/tmp/\n*.log\n")
      updater(path).ensure_patterns(PATTERNS)
      content = File.read(path)
      assert_includes content, "/tmp/"
      assert_includes content, "*.log"
      assert_includes content, ".claude/skills/gem-*"
    end
  end

  def test_appends_blank_line_when_no_trailing_newline
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitignore")
      File.write(path, "*.log") # no trailing newline
      updater(path).ensure_patterns(PATTERNS)
      content = File.read(path)
      assert_includes content, "*.log\n\n#{BundlerSkills::GitignoreUpdater::BEGIN_MARKER}"
    end
  end

  def test_rewrites_managed_block_when_patterns_change
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitignore")
      updater(path).ensure_patterns([".claude/skills/gem-*"])
      changed = updater(path).ensure_patterns(PATTERNS)
      assert changed
      content = File.read(path)
      assert_includes content, ".agents/skills/gem-*"
      # Only one managed block.
      assert_equal 1, content.scan(BundlerSkills::GitignoreUpdater::BEGIN_MARKER).size
    end
  end

  def test_empty_patterns_is_noop
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitignore")
      refute updater(path).ensure_patterns([])
      refute File.exist?(path)
    end
  end

  def test_dry_run_makes_no_changes
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".gitignore")
      changed = updater(path, dry_run: true).ensure_patterns(PATTERNS)
      assert changed # reports it would change
      refute File.exist?(path)
    end
  end
end
