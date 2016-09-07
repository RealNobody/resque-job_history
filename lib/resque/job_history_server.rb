require "resque"
require "resque/server"
require "resque-history"
require "action_view/helpers/date_helper"

module Resque
  # Extends Resque Web Based UI.
  # Structure has been borrowed from ResqueHistory.
  module JobHistoryServer
    include ActionView::Helpers::DateHelper

    def self.erb_path(filename)
      File.join(File.dirname(__FILE__), "server", "views", filename)
    end

    def self.public_path(filename)
      File.join(File.dirname(__FILE__), "server", "public", filename)
    end

    def self.included(base)
      base.class_eval do
        get "/job history" do
          @sort_by = params[:sort]
          erb File.read(Resque::JobHistoryServer.erb_path("job_history.erb"))
        end

        get "/job history/job_class_details" do
          @job_class_name = params[:class_name]
          erb File.read(Resque::JobHistoryServer.erb_path("job_class_details.erb"))
        end

        get "/job history/job_details" do
          @job_class_name = params[:class_name]
          @job_id         = params[:job_id]

          erb File.read(Resque::JobHistoryServer.erb_path("job_details.erb"))
        end

        post "/job history/cancel_job" do
          Resque::Plugins::JobHistory::ClassMethods.cancel_job params[:job_id], params[:class_name]

          redirect u("job history/job_details?#{{ class_name: params[:class_name],
                                                  job_id:     params[:job_id] }.to_param}")
        end

        post "/job history/delete_job" do
          Resque::Plugins::JobHistory::Cleaner::ClassMethods.purge_job params[:job_id], params[:class_name]

          redirect u("job history/job_class_details?#{{ class_name: params[:class_name] }.to_param}")
        end

        post "/job history/retry_job" do
          Resque::Plugins::JobHistory::ClassMethods.retry_job params[:job_id], params[:class_name]

          redirect u("job history/job_class_details?#{{ class_name: params[:class_name] }.to_param}")
        end

        post "/job history/purge_class" do
          Resque::Plugins::JobHistory::Cleaner::ClassMethods.purge_class params[:class_name]

          redirect u("job history")
        end

        post "/job history/purge_all" do
          Resque::Plugins::JobHistory::Cleaner::ClassMethods.purge_all_jobs

          redirect u("job history")
        end
      end
    end

    Resque::Server.tabs << "Job History"
  end

  # # Clears all historical jobs
  # def reset_history
  #   size = Resque.redis.llen(Resque::Plugins::History::HISTORY_SET_NAME)
  #
  #   size.times do
  #     Resque.redis.lpop(Resque::Plugins::History::HISTORY_SET_NAME)
  #   end
  # end
end

Resque.extend Resque::JobHistoryServer

Resque::Server.class_eval do
  include Resque::JobHistoryServer
end
