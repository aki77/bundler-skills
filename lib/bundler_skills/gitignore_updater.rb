# frozen_string_literal: true

module BundlerSkills
  # Keeps a managed block in .gitignore listing the generated symlink patterns
  # (e.g. .claude/skills/gem-*, .agents/skills/gem-*). The block is delimited by
  # marker comments so it can be detected and rewritten without touching the
  # rest of the file. Idempotent: re-running with the same patterns is a no-op.
  class GitignoreUpdater
    BEGIN_MARKER = "# >>> bundler-skills managed >>>"
    END_MARKER = "# <<< bundler-skills managed <<<"

    def initialize(gitignore_path:, dry_run: false)
      @gitignore_path = gitignore_path
      @dry_run = dry_run
    end

    # @param patterns [Array<String>] e.g. [".claude/skills/gem-*"]
    # @return [Boolean] true when the file was changed (or would be, in dry-run)
    def ensure_patterns(patterns)
      patterns = patterns.uniq
      return false if patterns.empty?

      existing = File.exist?(@gitignore_path) ? File.read(@gitignore_path) : nil
      updated = rewrite(existing, patterns)
      return false if updated == existing

      File.write(@gitignore_path, updated) unless @dry_run
      true
    end

    private

    def rewrite(existing, patterns)
      block = build_block(patterns)
      return block if existing.nil? || existing.empty?

      if existing.include?(BEGIN_MARKER) && existing.include?(END_MARKER)
        replace_block(existing, block)
      else
        separator = existing.end_with?("\n") ? "\n" : "\n\n"
        "#{existing}#{separator}#{block}"
      end
    end

    def build_block(patterns)
      lines = [BEGIN_MARKER, *patterns, END_MARKER]
      "#{lines.join("\n")}\n"
    end

    def replace_block(existing, block)
      pattern = /#{Regexp.escape(BEGIN_MARKER)}.*?#{Regexp.escape(END_MARKER)}\n?/m
      existing.sub(pattern, block)
    end
  end
end
