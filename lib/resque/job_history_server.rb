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
          @sort_by    = params[:sort] || "class_name"
          @sort_order = params[:order] || "asc"
          @page_num   = (params[:page_num] || 1).to_i
          @page_size  = (params[:page_size] || Resque::Plugins::JobHistory::PAGE_SIZE).to_i

          erb File.read(Resque::JobHistoryServer.erb_path("job_history.erb"))
        end

        get "/job history/job_class_details" do
          @job_class_name     = params[:class_name]
          @running_page_num   = (params[:running_page_num] || 1).to_i
          @running_page_size  = (params[:running_page_size] || Resque::Plugins::JobHistory::PAGE_SIZE).to_i
          @finished_page_num  = (params[:finished_page_num] || 1).to_i
          @finished_page_size = (params[:finished_page_size] || Resque::Plugins::JobHistory::PAGE_SIZE).to_i

          erb File.read(Resque::JobHistoryServer.erb_path("job_class_details.erb"))
        end

        get "/job history/job_details" do
          @job_class_name = params[:class_name]
          @job_id         = params[:job_id]

          erb File.read(Resque::JobHistoryServer.erb_path("job_details.erb"))
        end

        post "/job history/cancel_job" do
          Resque::Plugins::JobHistory.cancel_job params[:job_id], params[:class_name]

          redirect u("job history/job_details?#{{ class_name: params[:class_name],
                                                  job_id:     params[:job_id] }.to_param}")
        end

        post "/job history/delete_job" do
          Resque::Plugins::JobHistory::Cleaner.purge_job params[:job_id], params[:class_name]

          redirect u("job history/job_class_details?#{{ class_name: params[:class_name] }.to_param}")
        end

        post "/job history/retry_job" do
          Resque::Plugins::JobHistory.retry_job params[:job_id], params[:class_name]

          redirect u("job history/job_class_details?#{{ class_name: params[:class_name] }.to_param}")
        end

        post "/job history/purge_class" do
          Resque::Plugins::JobHistory::Cleaner.purge_class params[:class_name]

          redirect u("job history")
        end

        post "/job history/purge_all" do
          Resque::Plugins::JobHistory::Cleaner.purge_all_jobs

          redirect u("job history")
        end

        get %r{job_history/public/([a-z_]+\.[a-z]+)} do
          send_file Resque::JobHistoryServer.public_path(params[:captures].first)
        end
      end
    end

    Resque::Server.tabs << "Job History"
  end
end

Resque.extend Resque::JobHistoryServer

Resque::Server.class_eval do
  include Resque::JobHistoryServer
end
