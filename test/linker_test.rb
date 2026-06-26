# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class LinkerTest < Minitest::Test
  def cfg(data = {})
    BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS.merge(data))
  end

  # Create a source skill dir and return a DiscoveredSkill pointing at it.
  def skill(root, gem_name, skill_name)
    src = File.join(root, "src", gem_name, skill_name)
    FileUtils.mkdir_p(src)
    File.write(File.join(src, "SKILL.md"), "x")
    BundlerSkills::DiscoveredSkill.new(
      gem_name: gem_name, skill_name: skill_name, source_path: File.expand_path(src)
    )
  end

  def linker(dir, config: cfg)
    BundlerSkills::Linker.new(skills_dir: File.join(dir, ".claude", "skills"), config: config)
  end

  def link_path(dir, name)
    File.join(dir, ".claude", "skills", name)
  end

  def test_creates_absolute_symlink
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      result = linker(dir).link([s])
      path = link_path(dir, "gem-rubocop--style")
      assert File.symlink?(path)
      assert_equal s.source_path, File.readlink(path)
      assert File.absolute_path?(File.readlink(path))
      assert_equal ["gem-rubocop--style"], result.created
    end
  end

  def test_idempotent_keeps_correct_link
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      l = linker(dir)
      l.link([s])
      result = l.link([s])
      assert_equal ["gem-rubocop--style"], result.kept
      assert_empty result.created
    end
  end

  def test_relinks_when_target_changed
    Dir.mktmpdir do |dir|
      s1 = skill(dir, "rubocop", "style")
      linker(dir).link([s1])
      # Same link name (gem/skill), but the source moved to a new path.
      new_src = File.join(dir, "newsrc")
      FileUtils.mkdir_p(new_src)
      s_new = BundlerSkills::DiscoveredSkill.new(
        gem_name: "rubocop", skill_name: "style", source_path: File.expand_path(new_src)
      )
      result = linker(dir).link([s_new])
      assert_equal ["gem-rubocop--style"], result.relinked
      assert_equal File.expand_path(new_src), File.readlink(link_path(dir, "gem-rubocop--style"))
    end
  end

  def test_skips_real_directory_without_force
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      # Pre-create a real directory at the link path.
      real = link_path(dir, "gem-rubocop--style")
      FileUtils.mkdir_p(real)
      File.write(File.join(real, "user.md"), "mine")
      result = linker(dir).link([s])
      assert_equal ["gem-rubocop--style"], result.skipped
      refute File.symlink?(real)
      assert File.exist?(File.join(real, "user.md")), "user content must survive"
    end
  end

  def test_force_replaces_real_directory
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      real = link_path(dir, "gem-rubocop--style")
      FileUtils.mkdir_p(real)
      result = linker(dir, config: cfg("force" => true)).link([s])
      assert_equal ["gem-rubocop--style"], result.relinked
      assert File.symlink?(real)
    end
  end

  def test_prunes_stale_owned_symlinks
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      l = linker(dir)
      l.link([s]) # creates gem-rubocop--style
      # Now sync with an empty set -> the link is stale.
      result = l.link([])
      assert_equal ["gem-rubocop--style"], result.pruned
      refute File.exist?(link_path(dir, "gem-rubocop--style"))
    end
  end

  def test_prune_disabled_when_cleanup_false
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      linker(dir).link([s])
      result = linker(dir, config: cfg("cleanup" => false)).link([])
      assert_empty result.pruned
      assert File.symlink?(link_path(dir, "gem-rubocop--style"))
    end
  end

  def test_prune_leaves_unmanaged_entries
    Dir.mktmpdir do |dir|
      skills_dir = File.join(dir, ".claude", "skills")
      FileUtils.mkdir_p(skills_dir)
      # A real dir not matching our prefix, and a real dir with our prefix.
      FileUtils.mkdir_p(File.join(skills_dir, "my-own-skill"))
      FileUtils.mkdir_p(File.join(skills_dir, "gem-fake--real-dir"))
      result = linker(dir).link([])
      assert_empty result.pruned
      assert File.directory?(File.join(skills_dir, "my-own-skill"))
      assert File.directory?(File.join(skills_dir, "gem-fake--real-dir")), "real dir must not be pruned"
    end
  end

  def test_scoped_prune_only_touches_matching_prefix
    Dir.mktmpdir do |dir|
      l = linker(dir)
      l.link([skill(dir, "rubocop", "style"), skill(dir, "rspec", "matchers")])
      # Re-sync rubocop alone, scoped to its prefix, with no skills -> only the
      # rubocop link is pruned; rspec's link must survive.
      result = linker(dir).link([], prune_scope: ["gem-rubocop--"])
      assert_equal ["gem-rubocop--style"], result.pruned
      refute File.exist?(link_path(dir, "gem-rubocop--style"))
      assert File.symlink?(link_path(dir, "gem-rspec--matchers")), "other gem must be untouched"
    end
  end

  def test_scoped_prune_does_not_confuse_hyphenated_gem_names
    Dir.mktmpdir do |dir|
      l = linker(dir)
      # "rails" and "rails-html" share a leading "gem-rails" but differ at the
      # double-hyphen boundary; scoping to "gem-rails--" must not catch the other.
      l.link([skill(dir, "rails", "a"), skill(dir, "rails-html", "b")])
      result = linker(dir).link([], prune_scope: ["gem-rails--"])
      assert_equal ["gem-rails--a"], result.pruned
      assert File.symlink?(link_path(dir, "gem-rails-html--b")), "rails-html must survive"
    end
  end

  def test_prune_scope_nil_prunes_nothing
    Dir.mktmpdir do |dir|
      linker(dir).link([skill(dir, "rubocop", "style")])
      result = linker(dir).link([], prune_scope: nil)
      assert_empty result.pruned
      assert File.symlink?(link_path(dir, "gem-rubocop--style"))
    end
  end

  def test_clean_all_removes_owned_symlinks_only
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      l = linker(dir)
      l.link([s])
      skills_dir = File.join(dir, ".claude", "skills")
      FileUtils.mkdir_p(File.join(skills_dir, "my-own-skill")) # unmanaged real dir
      removed = l.clean_all
      assert_equal ["gem-rubocop--style"], removed
      refute File.exist?(File.join(skills_dir, "gem-rubocop--style"))
      assert File.directory?(File.join(skills_dir, "my-own-skill"))
    end
  end

  def test_dry_run_makes_no_changes
    Dir.mktmpdir do |dir|
      s = skill(dir, "rubocop", "style")
      result = linker(dir, config: cfg("dry_run" => true)).link([s])
      assert_equal ["gem-rubocop--style"], result.created
      refute File.exist?(link_path(dir, "gem-rubocop--style"))
    end
  end
end
