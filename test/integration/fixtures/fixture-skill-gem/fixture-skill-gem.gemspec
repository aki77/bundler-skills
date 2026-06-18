# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "fixture-skill-gem"
  spec.version = "0.1.0"
  spec.authors = ["test"]
  spec.summary = "fixture gem bundling skills"
  spec.files = Dir["lib/**/*.rb", "skills/**/*"]
  spec.require_paths = ["lib"]
end
