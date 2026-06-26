# frozen_string_literal: true

require "test_helper"
require "bundler"
require "bundler_skills/rubygems_hook"
require "tmpdir"
require "fileutils"

# Unit-tests the post_install entry point: context guard, disable switch,
# delegation to Synchronizer#sync_gem, and error containment. The real RubyGems
# dispatch (Gem.post_install -> block) is covered by the bundle-install E2E.
class RubygemsHookTest < Minitest::Test
  FakeSpec = Struct.new(:name, :version, :full_gem_path)
  FakeInstaller = Struct.new(:spec)

  def setup
    @saved = ENV["BUNDLER_SKILLS_DISABLED"]
    ENV.delete("BUNDLER_SKILLS_DISABLED")
  end

  def teardown
    ENV["BUNDLER_SKILLS_DISABLED"] = @saved
  end

  def test_syncs_the_installed_gem_in_bundle_context
    with_project do |dir|
      installer = FakeInstaller.new(fake_gem(dir, "rubocop", %w[style]))
      BundlerSkills::RubygemsHook.install(installer)
      link = File.join(dir, ".claude", "skills", "gem-rubocop--style")
      assert File.symlink?(link), "expected the installed gem's skill to be linked"
    end
  end

  def test_skips_when_disabled_flag_set
    with_project do |dir|
      ENV["BUNDLER_SKILLS_DISABLED"] = "1"
      installer = FakeInstaller.new(fake_gem(dir, "rubocop", %w[style]))
      BundlerSkills::RubygemsHook.install(installer)
      refute File.exist?(File.join(dir, ".claude", "skills", "gem-rubocop--style"))
    end
  end

  def test_skips_outside_bundle_context
    Dir.mktmpdir do |dir|
      # No Gemfile in dir -> not a bundle context.
      FileUtils.mkdir_p(File.join(dir, ".claude"))
      installer = FakeInstaller.new(fake_gem(dir, "rubocop", %w[style]))
      Bundler.stub(:root, Pathname.new(dir)) do
        BundlerSkills::RubygemsHook.install(installer)
      end
      refute File.exist?(File.join(dir, ".claude", "skills", "gem-rubocop--style"))
    end
  end

  def test_swallows_errors
    with_project do |dir|
      installer = FakeInstaller.new(fake_gem(dir, "rubocop", %w[style]))
      BundlerSkills::Synchronizer.stub(:new, ->(*) { raise "boom" }) do
        # Must not raise — bundle install should never be aborted by us.
        BundlerSkills::RubygemsHook.install(installer)
      end
    end
  end

  private

  # Sets up a tmp project with a Gemfile (so bundle_context? is true) and a
  # .claude marker, stubs Bundler.root/ui, and yields the dir.
  def with_project
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      FileUtils.mkdir_p(File.join(dir, ".claude"))
      Bundler.stub(:root, Pathname.new(dir)) do
        Bundler.stub(:ui, Bundler::UI::Silent.new) do
          yield dir
        end
      end
    end
  end

  def fake_gem(root, name, skills)
    path = File.join(root, "gems", name)
    skills.each do |s|
      d = File.join(path, "skills", s)
      FileUtils.mkdir_p(d)
      File.write(File.join(d, "SKILL.md"), "# #{s}")
    end
    FakeSpec.new(name, "1.0.0", path)
  end
end
