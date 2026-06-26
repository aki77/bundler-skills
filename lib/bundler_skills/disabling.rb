# frozen_string_literal: true

module BundlerSkills
  # Decides whether the post_install hook should run.
  #
  # The hook only fires when a gem is actually installed, and in the
  # recommended development-group setup the gem isn't even present in
  # production / CI — so there is no environment auto-detection here. The single
  # escape hatch is the BUNDLER_SKILLS_DISABLED env var. The manual CLI ignores
  # this entirely (running it is an explicit user action).
  module Disabling
    TRUTHY = %w[1 true yes on].freeze

    module_function

    # @param env [Hash] environment variables (defaults to ENV)
    # @return [Boolean] true when the hook must not run
    def disabled?(env: ENV)
      truthy?(env["BUNDLER_SKILLS_DISABLED"])
    end

    def truthy?(value)
      return false if value.nil?

      TRUTHY.include?(value.to_s.strip.downcase)
    end
  end
end
