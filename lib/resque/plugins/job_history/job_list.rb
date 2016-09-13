# frozen_string_literal: true

module Resque
  module Plugins
    module JobHistory
      # A class encompassing tasks about the jobs as a whole.
      #
      # This class gets a list of the classes and can provide a summary for each.
      class JobList < HistoryDetails
        def initialize
          super("")
        end

        def order_param(sort_option, current_sort, current_order)
          current_order ||= "asc"

          if sort_option == current_sort
            current_order == "asc" ? "desc" : "asc"
          else
            "asc"
          end
        end

        def job_summaries(sort_key = :class_name,
                          sort_order = "asc",
                          page_num = 1,
                          summary_page_size = Resque::Plugins::JobHistory::PAGE_SIZE)
          jobs = sorted_job_summaries(sort_key)

          page_start = (page_num - 1) * summary_page_size
          page_start = 0 if page_start > jobs.length

          (sort_order == "desc" ? jobs.reverse : jobs)[page_start..page_start + summary_page_size - 1]
        end

        def job_classes
          redis.smembers(Resque::Plugins::JobHistory::HistoryDetails.job_history_key)
        end

        def job_details(class_name)
          Resque::Plugins::JobHistory::HistoryDetails.new(class_name)
        end

        private

        def sorted_job_summaries(sort_key)
          job_classes.map { |class_name| job_details(class_name) }.sort_by do |job_details|
            summary_sort_value(job_details, sort_key)
          end
        end

        def summary_sort_value(job_details, sort_key)
          case sort_key.to_sym
            when :class_name,
                :num_running_jobs,
                :num_finished_jobs,
                :total_finished_jobs,
                :total_run_jobs,
                :max_concurrent_jobs
              job_details.public_send sort_key
            else
              last_run_sort_value(job_details.last_run, sort_key)
          end
        end

        def last_run_sort_value(last_run, sort_key)
          case sort_key.to_sym
            when :start_time
              last_run.start_time || Time.now
            when :duration
              last_run.duration
            when :success
              last_run.succeeded? ? 1 : 0
          end
        end
      end
    end
  end
end
