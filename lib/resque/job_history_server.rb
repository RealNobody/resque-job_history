# frozen_string_literal: true

require "resque"
require "resque/server"
require "resque-job_history"
require "action_view/helpers/output_safety_helper"
require "action_view/helpers/capture_helper"
require "action_view/helpers/date_helper"

module Resque
  # Extends Resque Web Based UI.
  # Structure has been borrowed from ResqueHistory.
  module JobHistoryServer
    include ActionView::Helpers::DateHelper

    class << self
      def erb_path(filename)
        File.join(File.dirname(__FILE__), "server", "views", filename)
      end

      def public_path(filename)
        File.join(File.dirname(__FILE__), "server", "public", filename)
      end

      def included(base)
        add_page_views(base)
        add_button_callbacks(base)
        add_static_files(base)
      end

      private

      def add_page_views(base)
        job_history(base)
        class_details(base)
        job_details(base)
        linear_list(base)
      end

      def job_history(base)
        job_history_params(base)

        base.class_eval do
          get "/job%20history" do
            set_job_history_params

            erb File.read(Resque::JobHistoryServer.erb_path("job_history.erb"))
          end
        end
      end

      def job_history_params(base)
        base.class_eval do
          def set_job_history_params
            @sort_by    = params[:sort] || "start_time"
            @sort_order = params[:order] || "desc"
            @page_num   = (params[:page_num] || 1).to_i
            @page_size  = (params[:page_size] ||
                Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size).to_i
          end
        end
      end

      def class_details(base)
        class_details_params(base)
        running_page_params(base)
        finished_page_params(base)

        base.class_eval do
          get "/job%20history/job_class_details" do
            set_class_details_params

            erb File.read(Resque::JobHistoryServer.erb_path("job_class_details.erb"))
          end
        end
      end

      def class_details_params(base)
        base.class_eval do
          def set_class_details_params
            @job_class_name = params[:class_name]
            set_running_page_params
            set_finished_page_params
          end
        end
      end

      def running_page_params(base)
        base.class_eval do
          def set_running_page_params
            @running_page_num  = (params[:running_page_num] || 1).to_i
            @running_page_size = (params[:running_page_size] ||
                Resque::Plugins::JobHistory::HistoryDetails.new(@job_class_name).page_size).to_i
          end
        end
      end

      def finished_page_params(base)
        base.class_eval do
          def set_finished_page_params
            @finished_page_num  = (params[:finished_page_num] || 1).to_i
            @finished_page_size = (params[:finished_page_size] ||
                Resque::Plugins::JobHistory::HistoryDetails.new(@job_class_name).page_size).to_i
          end
        end
      end

      def job_details(base)
        base.class_eval do
          get "/job%20history/job_details" do
            @job_class_name = params[:class_name]
            @job_id         = params[:job_id]

            erb File.read(Resque::JobHistoryServer.erb_path("job_details.erb"))
          end
        end
      end

      def linear_list(base)
        base.class_eval do
          get "/job%20history/linear_history" do
            @page_num  = (params[:page_num] || 1).to_i
            @page_size = (params[:page_size] ||
                Resque::Plugins::JobHistory::HistoryDetails.linear_page_size).to_i

            erb File.read(Resque::JobHistoryServer.erb_path("linear_history.erb"))
          end
        end
      end

      def add_static_files(base)
        base.class_eval do
          get %r{job_history/public/([a-z_]+\.[a-z]+)} do
            send_file Resque::JobHistoryServer.public_path(params[:captures].first)
          end
        end
      end

      def add_button_callbacks(base)
        purge_all(base)
        purge_linear_history(base)
        purge_class(base)
        retry_job(base)
        delete_job(base)
        cancel_job(base)
        search_all(base)
        search_job(base)
        search_linear_history(base)
      end

      def cancel_job(base)
        base.class_eval do
          post "/job%20history/cancel_job" do
            Resque::Plugins::JobHistory::Job.new(params[:class_name], params[:job_id]).cancel

            redirect u("job history/job_details?#{{ class_name: params[:class_name],
                                                    job_id:     params[:job_id] }.to_param}")
          end
        end
      end

      def delete_job(base)
        base.class_eval do
          post "/job%20history/delete_job" do
            Resque::Plugins::JobHistory::Job.new(params[:class_name], params[:job_id]).purge

            redirect u("job history/job_class_details?#{{ class_name: params[:class_name] }.to_param}")
          end
        end
      end

      def retry_job(base)
        base.class_eval do
          post "/job%20history/retry_job" do
            Resque::Plugins::JobHistory::Job.new(params[:class_name], params[:job_id]).retry

            redirect u("job history/job_class_details?#{{ class_name: params[:class_name] }.to_param}")
          end
        end
      end

      def purge_class(base)
        base.class_eval do
          post "/job%20history/purge_class" do
            Resque::Plugins::JobHistory::Cleaner.purge_class(params[:class_name])

            redirect u("job history")
          end
        end
      end

      def purge_all(base)
        base.class_eval do
          post "/job%20history/purge_all" do
            Resque::Plugins::JobHistory::Cleaner.purge_all_jobs

            redirect u("job history")
          end
        end
      end

      def purge_linear_history(base)
        base.class_eval do
          post "/job%20history/purge_linear_history" do
            Resque::Plugins::JobHistory::Cleaner.purge_linear_history

            redirect u("job history")
          end
        end
      end

      def search_all(base)
        base.class_eval do
          post "/job%20history/search_all" do
            @job_search = Resque::Plugins::JobHistory::JobSearch.new(params)

            @job_search.search

            erb File.read(Resque::JobHistoryServer.erb_path("search_results.erb"))
          end
        end
      end

      def search_job(base)
        base.class_eval do
          post "/job%20history/search_job" do
            @job_search = Resque::Plugins::JobHistory::JobSearch.new(params)

            @job_search.search

            erb File.read(Resque::JobHistoryServer.erb_path("search_results.erb"))
          end
        end
      end

      def search_linear_history(base)
        base.class_eval do
          post "/job%20history/search_linear_history" do
            @job_search = Resque::Plugins::JobHistory::JobSearch.new(params)

            @job_search.search

            erb File.read(Resque::JobHistoryServer.erb_path("search_results.erb"))
          end
        end
      end
    end

    Resque::Server.tabs << "Job History"
  end
end

Resque::Server.class_eval do
  include Resque::JobHistoryServer
end
