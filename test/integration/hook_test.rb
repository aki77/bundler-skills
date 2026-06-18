# frozen_string_literal: true

require "test_helper"
require "bundler"

# Exercises Hook.call directly: the disabling guard + delegation to
# Synchronizer, plus error containment.
#
# The full Bundler::Plugin dispatch path (after-install-all -> add_hook block)
# requires a real installed plugin index, so it is covered by the
# bundle-install end-to-end test (see test/integration/bundle_install_test.rb),
# not here.
class HookTest < Minitest::Test
  def setup
    Bundler.ui = Bundler::UI::Shell.new
    @saved_env = ENV.to_h.slice("CI", "RAILS_ENV", "RACK_ENV", "BUNDLER_SKILLS_DISABLED")
    %w[CI RAILS_ENV RACK_ENV BUNDLER_SKILLS_DISABLED].each { |k| ENV.delete(k) }
    stub_config_load
  end

  def teardown
    %w[CI RAILS_ENV RACK_ENV BUNDLER_SKILLS_DISABLED].each { |k| ENV.delete(k) }
    @saved_env.each { |k, v| ENV[k] = v }
    BundlerSkills::Config.define_singleton_method(:load, @original_load)
    BundlerSkills::Synchronizer.define_method(:sync, @original_sync) if @original_sync
  end

  def test_call_runs_sync_in_dev_environment
    assert_equal 1, count_syncs { BundlerSkills::Hook.call }
  end

  def test_call_skips_sync_in_ci
    ENV["CI"] = "true"
    assert_equal 0, count_syncs { BundlerSkills::Hook.call }
  end

  def test_call_skips_sync_when_disabled_flag_set
    ENV["BUNDLER_SKILLS_DISABLED"] = "1"
    assert_equal 0, count_syncs { BundlerSkills::Hook.call }
  end

  def test_call_swallows_sync_errors
    @original_sync = BundlerSkills::Synchronizer.instance_method(:sync)
    BundlerSkills::Synchronizer.define_method(:sync) { raise "boom" }
    # Must not raise — bundle install should never be aborted by us.
    BundlerSkills::Hook.call
  end

  private

  def stub_config_load
    @original_load = BundlerSkills::Config.method(:load)
    BundlerSkills::Config.define_singleton_method(:load) do |*|
      BundlerSkills::Config.new(BundlerSkills::Config::DEFAULTS)
    end
  end

  def count_syncs
    calls = 0
    @original_sync = BundlerSkills::Synchronizer.instance_method(:sync)
    BundlerSkills::Synchronizer.define_method(:sync) { calls += 1 }
    yield
    calls
  end
end
