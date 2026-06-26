# frozen_string_literal: true

require "test_helper"

class DisablingTest < Minitest::Test
  def disabled?(env: {})
    BundlerSkills::Disabling.disabled?(env: env)
  end

  def test_enabled_by_default_in_plain_env
    refute disabled?(env: {})
  end

  def test_disabled_flag_wins
    assert disabled?(env: { "BUNDLER_SKILLS_DISABLED" => "1" })
  end

  # production / CI are no longer auto-detected: the hook only fires when a gem
  # is actually installed (in the recommended development-group setup it isn't
  # even present in production / CI), so the single switch is the env var.
  def test_production_no_longer_disables
    refute disabled?(env: { "RAILS_ENV" => "production" })
    refute disabled?(env: { "RACK_ENV" => "production" })
  end

  def test_ci_no_longer_disables
    refute disabled?(env: { "CI" => "true" })
  end

  def test_truthy_variants
    %w[1 true yes on TRUE Yes].each do |v|
      assert disabled?(env: { "BUNDLER_SKILLS_DISABLED" => v }), "expected #{v} truthy"
    end
    ["0", "false", "", "no", nil].each do |v|
      refute disabled?(env: { "BUNDLER_SKILLS_DISABLED" => v }), "expected #{v.inspect} falsy"
    end
  end
end
