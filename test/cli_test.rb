# frozen_string_literal: true

require "test_helper"
require "bundler"
require "bundler_skills/cli"
require "tmpdir"
require "yaml"
require "open3"
require "fileutils"

class CLITest < Minitest::Test
  class CapturingLogger
    attr_reader :infos, :warns, :errors

    def initialize
      @infos = []
      @warns = []
      @errors = []
    end

    def info(msg)    = @infos << msg
    def confirm(msg) = @infos << msg
    def warn(msg)    = @warns << msg
    def error(msg)   = @errors << msg
  end

  def setup
    @logger = CapturingLogger.new
    @cli = BundlerSkills::CLI.new(logger: @logger)
  end

  def test_init_template_is_valid_yaml
    result = YAML.safe_load(BundlerSkills::CLI::INIT_TEMPLATE)
    assert_nil result, "template should parse as nil (all lines are comments)"
  end

  def test_help_prints_usage_and_exits_zero
    assert_equal 0, @cli.run(["--help"])
    assert_match(/Usage: bundler-skills/, @logger.infos.join("\n"))
  end

  def test_unknown_subcommand_returns_nonzero
    assert_equal 1, @cli.run(["bogus"])
    assert_match(/unknown subcommand: bogus/, @logger.errors.join("\n"))
  end

  def test_init_creates_config_file
    Dir.mktmpdir do |dir|
      stub_bundler_root(dir) do
        assert_equal 0, @cli.run(["init"])
        path = File.join(dir, BundlerSkills::Config::CONFIG_FILENAME)
        assert File.exist?(path), "bundler-skills.yml should be created"
        assert_equal BundlerSkills::CLI::INIT_TEMPLATE, File.read(path)
      end
    end
  end

  def test_init_does_not_overwrite_existing_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, BundlerSkills::Config::CONFIG_FILENAME)
      File.write(path, "agents:\n  - claude\n")
      stub_bundler_root(dir) do
        @cli.run(["init"])
        assert_equal "agents:\n  - claude\n", File.read(path),
                     "existing config should not be overwritten"
      end
    end
  end

  # Regression: the global executable is meant to run directly from PATH, not
  # only via `bundle exec`. Its `require "bundler"` line must be present so that
  # `Config.load(root: Bundler.root)` doesn't crash with an uninitialized
  # constant. Run exe/bundler-skills in a subprocess with a clean env (no
  # `bundle exec`, no inherited BUNDLE_GEMFILE) inside a real project.
  def test_bare_execution_without_bundle_exec_works
    exe = File.expand_path("../exe/bundler-skills", __dir__)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      File.write(File.join(dir, BundlerSkills::Config::CONFIG_FILENAME), "")
      FileUtils.mkdir_p(File.join(dir, ".claude"))

      env = {
        "BUNDLE_GEMFILE" => File.join(dir, "Gemfile"),
        "RUBYLIB" => File.expand_path("../lib", __dir__)
      }
      out, status = Bundler.with_unbundled_env do
        Open3.capture2e(env, RbConfig.ruby, exe, "list", chdir: dir)
      end

      assert status.success?, "bare `bundler-skills list` should exit 0:\n#{out}"
      refute_match(/uninitialized constant.*Bundler/, out,
                   "require \"bundler\" must be present so Bundler.root resolves")
    end
  end

  private

  def stub_bundler_root(dir)
    Bundler.stub(:root, Pathname.new(dir)) { yield }
  end
end
