# frozen_string_literal: true

require "test_helper"
require "bundler_skills/command"
require "tmpdir"
require "yaml"

class CommandTest < Minitest::Test
  def setup
    @cmd = BundlerSkills::Command.new
  end

  def test_init_template_is_valid_yaml
    result = YAML.safe_load(BundlerSkills::Command::INIT_TEMPLATE)
    assert_nil result, "template should parse as nil (all lines are comments)"
  end

  def test_init_creates_config_file
    Dir.mktmpdir do |dir|
      stub_bundler_root(dir) do
        @cmd.send(:run_init)

        path = File.join(dir, BundlerSkills::Config::CONFIG_FILENAME)
        assert File.exist?(path), "bundler-skills.yml should be created"
        assert_equal BundlerSkills::Command::INIT_TEMPLATE, File.read(path)
      end
    end
  end

  def test_init_does_not_overwrite_existing_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, BundlerSkills::Config::CONFIG_FILENAME)
      File.write(path, "agents:\n  - claude\n")

      stub_bundler_root(dir) do
        @cmd.send(:run_init)

        assert_equal "agents:\n  - claude\n", File.read(path),
                     "existing config should not be overwritten"
      end
    end
  end

  private

  def stub_bundler_root(dir)
    ui = Bundler::UI::Silent.new
    Bundler.stub(:root, Pathname.new(dir)) do
      Bundler.stub(:ui, ui) do
        yield
      end
    end
  end
end
