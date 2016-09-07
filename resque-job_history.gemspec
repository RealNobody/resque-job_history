$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "resque/plugins/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "resque-job_history"
  s.version     = Resque::Plugins::JobHistory::VERSION
  s.authors     = ["RealNobody"]
  s.email       = ["RealNobody1@cox.net"]
  s.homepage    = "https://github.com/RealNobody"
  s.summary     = "Keeps a history of run jobs by job."
  s.description = "Keeps a history of run jobs by job."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2"
  s.add_dependency "resque", "~> 1.25"
  s.add_dependency "redis-namespace"
  s.add_dependency "redis"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
end
