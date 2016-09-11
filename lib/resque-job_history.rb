# frozen_string_literal: true

require "resque"
require File.expand_path(File.join("resque", "plugins", "job_history", "history_details"),
                         File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "job_history", "history_list"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "job_history", "job_list"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "job_history", "job"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "job_history", "cleaner"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "job_history"), File.dirname(__FILE__))
