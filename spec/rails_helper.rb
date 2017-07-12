# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "spec_helper"
require "cornucopia/rspec_hooks"
require "active_job"
require "resque-job_history"
require "yaml"
require "timecop"
require "faker"
require "rack/test"
require "resque/server"
require "resque/job_history_server"

Dir[File.expand_path("spec/support/**/*.rb"), File.dirname(__FILE__)].each do |f|
  require f unless File.directory?(f)
end

FileUtils.mkdir_p(File.expand_path("../log", File.dirname(__FILE__)))

redis_logger           = Logger.new(File.expand_path("../log/redis.log", File.dirname(__FILE__)))
redis_logger.level     = Logger::DEBUG
redis_logger.formatter = Logger::Formatter.new

redis_options = YAML.load_file(File.expand_path("support/config/redis-auth.yml", File.dirname(__FILE__)))
Redis.current = Redis.new(redis_options.merge(logger: redis_logger))

Resque.redis  = Redis.new(redis_options)
Resque.inline = true

# Cornucopia::Util::Configuration.context_seed = 1
# Cornucopia::Util::Configuration.seed         = 1
# Cornucopia::Util::Configuration.order_seed   = 1
