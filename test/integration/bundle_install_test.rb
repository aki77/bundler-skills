# frozen_string_literal: true

require "test_helper"
require "bundler"
require "tmpdir"
require "fileutils"
require "open3"

# End-to-end: runs a real `bundle install` in a temp project. bundler-skills is
# now a regular gem whose lib/rubygems_plugin.rb registers a Gem.post_install
# hook; the manual command is exe/skills (`bundle exec skills`).
#
# Both bundler-skills and the fixture gem are installed from GIT sources. This
# matters: path sources are not "installed" (extracted) by Bundler, so the
# RubyGems post_install hook never fires for them — git/rubygems sources do.
class BundleInstallIntegrationTest < Minitest::Test
  REPO = File.expand_path("../..", __dir__)
  FIXTURE = File.expand_path("fixtures/fixture-skill-gem", __dir__)

  def setup
    skip "bundler not available" unless system("bundle", "--version", out: File::NULL, err: File::NULL)
    @tmp = Dir.mktmpdir
    @bs_repo = git_repo_from(REPO, "bundler-skills", files: %w[lib exe bundler-skills.gemspec README.md])
    @fx_repo = git_repo_from(FIXTURE, "fixture-skill-gem")
  end

  def teardown
    FileUtils.remove_entry(@tmp) if @tmp && File.directory?(@tmp)
  end

  def test_post_install_links_skills_and_command_works
    in_project(markers: %w[.claude]) do |dir|
      out = bundle_install(dir)
      assert_match(/created:/, out)

      demo = File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo")
      assert File.symlink?(demo), "expected symlink for demo skill\n#{out}"
      assert File.absolute_path?(File.readlink(demo))

      # gitignore written
      assert_includes File.read(File.join(dir, ".gitignore")), ".claude/skills/gem-*"

      # manual command works via `bundle exec skills`
      list = bundle_exec(dir, "skills", "list")
      assert_match(/gem-fixture-skill-gem--demo/, list)
    end
  end

  def test_scoped_prune_when_gem_skill_removed_keeps_other_gems
    in_project(markers: %w[.claude]) do |dir|
      bundle_install(dir)
      assert File.symlink?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo"))
      assert File.symlink?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--other"))

      # New fixture version drops the "other" skill.
      drop_skill_and_bump(@fx_repo, "other", "0.2.0")
      bundle_update(dir, "fixture-skill-gem")

      refute File.exist?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--other")),
             "the removed skill's link should be pruned"
      assert File.symlink?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo")),
             "the surviving skill's link should remain"
    end
  end

  def test_self_update_does_not_raise_command_conflict
    in_project(markers: %w[.claude]) do |dir|
      bundle_install(dir)
      bump_version(@bs_repo, "0.3.0", "9.9.9")
      out = bundle_update(dir, "bundler-skills")
      refute_match(/CommandConflict/, out, "regular gem must not raise CommandConflict on self-update")
    end
  end

  def test_disabled_via_env
    in_project(markers: %w[.claude]) do |dir|
      bundle_install(dir, env: { "BUNDLER_SKILLS_DISABLED" => "1" })
      refute File.exist?(File.join(dir, ".claude", "skills", "gem-fixture-skill-gem--demo")),
             "BUNDLER_SKILLS_DISABLED should suppress linking"
    end
  end

  private

  def in_project(markers:)
    dir = File.join(@tmp, "project-#{markers.join('_')}-#{rand(10_000)}")
    markers.each { |m| FileUtils.mkdir_p(File.join(dir, m)) }
    write_gemfile(dir)
    yield dir
  end

  def write_gemfile(dir)
    File.write(File.join(dir, "Gemfile"), <<~RB)
      source "https://rubygems.org"
      group :development do
        gem "bundler-skills", git: "file://#{@bs_repo}"
        gem "fixture-skill-gem", git: "file://#{@fx_repo}"
      end
    RB
  end

  # Snapshot a source dir into a throwaway git repo (post_install fires for git
  # sources but not path sources).
  def git_repo_from(src, name, files: nil)
    repo = File.join(@tmp, name)
    FileUtils.mkdir_p(repo)
    entries = files || Dir.children(src).reject { |e| e == ".git" }
    entries.each do |e|
      from = File.join(src, e)
      FileUtils.cp_r(from, File.join(repo, e)) if File.exist?(from)
    end
    FileUtils.chmod(0o755, File.join(repo, "exe", "skills")) if File.exist?(File.join(repo, "exe", "skills"))
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "t@e.com")
    git(repo, "config", "user.name", "t")
    git(repo, "add", "-A")
    git(repo, "commit", "-qm", "snapshot")
    repo
  end

  def drop_skill_and_bump(repo, skill, version)
    FileUtils.rm_rf(File.join(repo, "skills", skill))
    bump_fixture_version(repo, version)
    git(repo, "add", "-A")
    git(repo, "commit", "-qm", "v#{version}")
  end

  def bump_fixture_version(repo, version)
    path = File.join(repo, "fixture-skill-gem.gemspec")
    File.write(path, File.read(path).sub(/version\s*=\s*"[^"]+"/, %(version = "#{version}")))
  end

  def bump_version(repo, from, to)
    path = File.join(repo, "lib", "bundler_skills", "version.rb")
    File.write(path, File.read(path).sub(from, to))
    git(repo, "add", "-A")
    git(repo, "commit", "-qm", "v#{to}")
  end

  def git(repo, *args)
    out, status = Open3.capture2e(git_env, "git", "-C", repo, *args)
    raise "git #{args.join(' ')} failed:\n#{out}" unless status.success?
  end

  # Neutralize host safe.bareRepository / safe.directory that block Bundler's
  # git plugin clone in some environments.
  def git_env
    {
      "GIT_CONFIG_COUNT" => "2",
      "GIT_CONFIG_KEY_0" => "safe.bareRepository", "GIT_CONFIG_VALUE_0" => "all",
      "GIT_CONFIG_KEY_1" => "safe.directory", "GIT_CONFIG_VALUE_1" => "*"
    }
  end

  def bundle_install(dir, env: {})
    run_bundle(dir, env, "install")
  end

  def bundle_update(dir, *gems, env: {})
    run_bundle(dir, env, "update", *gems)
  end

  def bundle_exec(dir, *cmd, env: {})
    run_bundle(dir, env, "exec", *cmd)
  end

  def run_bundle(dir, env, *args)
    clean_env = {
      "CI" => nil, "RAILS_ENV" => nil, "RACK_ENV" => nil,
      "BUNDLER_SKILLS_DISABLED" => nil, "BUNDLE_GEMFILE" => nil
    }.merge(git_env).merge(env)
    out, status = Bundler.with_unbundled_env do
      Open3.capture2e(clean_env, "bundle", *args, chdir: dir)
    end
    assert status.success?, "bundle #{args.join(' ')} failed:\n#{out}"
    out
  end
end
