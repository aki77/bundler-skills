# frozen_string_literal: true

require "test_helper"
require "bundler"
require "bundler_skills/cli"
require "tmpdir"
require "yaml"

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
    assert_match(/Usage: bundle exec skills/, @logger.infos.join("\n"))
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

  private

  def stub_bundler_root(dir)
    Bundler.stub(:root, Pathname.new(dir)) { yield }
  end
end
