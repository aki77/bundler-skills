# frozen_string_literal: true

require "test_helper"
require "bundler"
require "tmpdir"
require "fileutils"
require "open3"

# End-to-end: runs a real `bundle install` in a temp project with the plugin
# loaded via a path source and a fixture gem that bundles skills. Exercises the
# whole hook path that unit tests can't (Bundler::Plugin dispatch).
#
# Uses `plugin "...", path:` to avoid the git plugin-cache re-fetch issue.
class BundleInstallIntegrationTest < Minitest::Test
  REPO = File.expand_path("../..", __dir__)
  FIXTURE = File.expand_path("fixtures/fixture-skill-gem", __dir__)

  def setup
    skip "bundler not available" unless system("bundle", "--version", out: File::NULL, err: File::NULL)
  end

  def test_links_skills_for_detected_agent_and_is_idempotent
    in_project(markers: %w[.claude]) do |dir|
      out1 = bundle_install(dir)
      assert_match(/bundler-skills\].*linked/, out1)

      demo = File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo")
      assert File.symlink?(demo), "expected symlink for demo skill"
      assert_equal File.join(FIXTURE, "skills", "demo"), File.readlink(demo)
      assert File.absolute_path?(File.readlink(demo))

      # gitignore written
      gitignore = File.read(File.join(dir, ".gitignore"))
      assert_includes gitignore, ".claude/skills/gem-*"

      # idempotent second run: still exactly 2 links, one managed block
      bundle_install(dir)
      links = Dir.children(File.join(dir, ".claude", "skills"))
      assert_equal 2, links.size
      assert_equal 1, File.read(File.join(dir, ".gitignore")).scan("bundler-skills managed >>>").size
    end
  end

  def test_multi_agent_dedup
    in_project(markers: %w[.claude .cursor]) do |dir|
      bundle_install(dir)
      assert File.symlink?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo"))
      assert File.symlink?(File.join(dir, ".agents", "skills", "gem-fixture-skill-gem--demo"))
    end
  end

  def test_disabled_in_ci
    in_project(markers: %w[.claude]) do |dir|
      bundle_install(dir, env: { "CI" => "true" })
      refute File.exist?(File.join(dir, ".claude", "skills")),
             "no skills should be linked under CI"
    end
  end

  def test_prunes_when_gem_removed
    in_project(markers: %w[.claude]) do |dir|
      bundle_install(dir)
      assert File.symlink?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo"))

      write_gemfile(dir, with_fixture: false)
      bundle_install(dir)
      refute File.exist?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo"))
    end
  end

  private

  def in_project(markers:)
    Dir.mktmpdir do |dir|
      markers.each { |m| FileUtils.mkdir_p(File.join(dir, m)) }
      write_gemfile(dir, with_fixture: true)
      yield dir
    end
  end

  def write_gemfile(dir, with_fixture:)
    lines = [
      'source "https://rubygems.org"',
      %(plugin "bundler-skills", path: "#{REPO}")
    ]
    lines << %(gem "fixture-skill-gem", path: "#{FIXTURE}") if with_fixture
    lines << 'gem "rake"' unless with_fixture
    File.write(File.join(dir, "Gemfile"), "#{lines.join("\n")}\n")
  end

  def bundle_install(dir, env: {})
    clean_env = {
      "CI" => nil, "RAILS_ENV" => nil, "RACK_ENV" => nil,
      "BUNDLER_SKILLS_DISABLED" => nil, "BUNDLE_GEMFILE" => nil
    }.merge(env)
    out, status = Bundler.with_unbundled_env do
      Open3.capture2e(clean_env, "bundle", "install", chdir: dir)
    end
    assert status.success?, "bundle install failed:\n#{out}"
    out
  end
end
