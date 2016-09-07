require "resque"
require File.expand_path(File.join("resque", "plugins", "job_history", "job_viewer"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "job_history", "cleaner"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "job_history"), File.dirname(__FILE__))
