# frozen_string_literal: true

require "test_helper"

class DisablingTest < Minitest::Test
  Config = Struct.new(:enabled)

  def disabled?(env: {}, config: nil)
    BundlerSkills::Disabling.disabled?(env: env, config: config)
  end

  def test_enabled_by_default_in_plain_env
    refute disabled?(env: {})
  end

  def test_disabled_flag_wins
    assert disabled?(env: { "BUNDLER_SKILLS_DISABLED" => "1" })
  end

  def test_enabled_flag_overrides_production
    refute disabled?(env: { "BUNDLER_SKILLS_ENABLED" => "1", "RAILS_ENV" => "production" })
  end

  def test_disabled_flag_beats_enabled_flag
    assert disabled?(env: { "BUNDLER_SKILLS_DISABLED" => "1", "BUNDLER_SKILLS_ENABLED" => "1" })
  end

  def test_production_rails_env
    assert disabled?(env: { "RAILS_ENV" => "production" })
  end

  def test_production_rack_env
    assert disabled?(env: { "RACK_ENV" => "production" })
  end

  def test_ci
    assert disabled?(env: { "CI" => "true" })
  end

  def test_development_rails_env_is_enabled
    refute disabled?(env: { "RAILS_ENV" => "development" })
  end

  def test_config_enabled_false_disables
    assert disabled?(env: {}, config: Config.new(false))
  end

  def test_config_enabled_true_overrides_ci
    refute disabled?(env: { "CI" => "1" }, config: Config.new(true))
  end

  def test_config_enabled_list_includes_current
    refute disabled?(env: { "RAILS_ENV" => "staging" }, config: Config.new(%w[development staging]))
  end

  def test_config_enabled_list_excludes_current
    assert disabled?(env: { "RAILS_ENV" => "staging" }, config: Config.new(%w[development]))
  end

  def test_config_enabled_list_defaults_to_development_when_no_env
    refute disabled?(env: {}, config: Config.new(%w[development]))
    assert disabled?(env: {}, config: Config.new(%w[production]))
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
