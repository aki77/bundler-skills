# frozen_string_literal: true

module BundlerSkills
  # Decides whether the plugin should run in the current environment.
  #
  # Skills are a development-time concern, so the hook is silently disabled in
  # production / CI. All inputs are injected (env hash + config) so the logic is
  # a pure function and easy to test. The manual `bundle skills` command does
  # NOT consult this — an explicit user action always runs.
  module Disabling
    TRUTHY = %w[1 true yes on].freeze

    module_function

    # @param env [Hash] environment variables (defaults to ENV)
    # @param config [BundlerSkills::Config, nil] loaded config (optional)
    # @return [Boolean] true when the plugin must not run
    def disabled?(env: ENV, config: nil)
      # Explicit overrides win over everything else.
      return true if truthy?(env["BUNDLER_SKILLS_DISABLED"])
      return false if truthy?(env["BUNDLER_SKILLS_ENABLED"])

      enabled = config&.enabled
      case enabled
      when false
        return true
      when Array
        return true unless enabled.map(&:to_s).include?(current_environment(env))
      when true
        return false
      end

      production?(env) || ci?(env)
    end

    def truthy?(value)
      return false if value.nil?

      TRUTHY.include?(value.to_s.strip.downcase)
    end

    def production?(env)
      %w[RAILS_ENV RACK_ENV].any? { |key| env[key].to_s.strip.downcase == "production" }
    end

    def ci?(env)
      truthy?(env["CI"])
    end

    # Best-effort current environment name for `enabled:` list matching.
    def current_environment(env)
      value = env["RAILS_ENV"] || env["RACK_ENV"]
      value.to_s.strip.empty? ? "development" : value.strip.downcase
    end
  end
end
