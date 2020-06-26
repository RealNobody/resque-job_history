# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "resque-job_history"
  s.version     = "0.0.18"
  s.authors     = ["RealNobody"]
  s.email       = ["RealNobody1@cox.net"]
  s.homepage    = "https://github.com/RealNobody"
  s.summary     = "Keeps a history of run jobs by job."
  s.description = "Keeps a history of run jobs by job."
  s.license     = "MIT"

  s.files      = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  # s.add_dependency "rails", "~> 3.2"
  s.add_dependency "resque"
  s.add_dependency "sinatra", ">= 2.0.7"
  s.add_dependency "redis-namespace"
  s.add_dependency "redis"

  # s.add_development_dependency "sqlite3"
  s.add_development_dependency "actionpack"
  s.add_development_dependency "activejob"
  s.add_development_dependency "activesupport"
  s.add_development_dependency "rspec-rails", ">= 3.6.0"
  s.add_development_dependency "gem-release"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "cornucopia"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "haml-lint"
  s.add_development_dependency "timecop"
  s.add_development_dependency "faker"
  s.add_development_dependency "rack-test"
end
