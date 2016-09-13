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

        def job_class_summary(class_name)
          history = Resque::Plugins::JobHistory::HistoryDetails.new(class_name)

          running_list  = history.running_jobs
          finished_list = history.finished_jobs

          class_summary_hash(class_name, finished_list, running_list)
        end

        private

        def latest_job(running_list, finished_list)
          running_list.latest_job || finished_list.latest_job
        end

        def sorted_job_summaries(sort_key)
          job_classes.map { |class_name| job_class_summary(class_name) }.sort_by do |job_summary|
            summary_sort_value(job_summary, sort_key)
          end
        end

        def summary_sort_value(job_summary, sort_key)
          case sort_key.to_sym
            when :class_name,
                :running_jobs,
                :finished_jobs,
                :total_finished_jobs,
                :total_run_jobs,
                :max_running_jobs
              job_summary[sort_key.to_sym]
            when :start_time
              job_summary[:last_run].start_time
            when :duration
              job_summary[:last_run].duration
            when :success
              job_summary[:last_run].succeeded? ? 1 : 0
          end
        end

        def class_summary_hash(class_name, finished_list, running_list)
          { class_name:          class_name,
            class_name_valid:    running_list.class_name_valid?,
            running_jobs:        running_list.num_jobs,
            finished_jobs:       finished_list.num_jobs,
            total_run_jobs:      running_list.total,
            total_finished_jobs: finished_list.total,
            max_concurrent_jobs: Resque::Plugins::JobHistory::HistoryDetails.new(class_name).
                max_concurrent_jobs,
            total_failed_jobs:   Resque::Plugins::JobHistory::HistoryDetails.new(class_name).
                total_failed_jobs,
            last_run:            latest_job(running_list, finished_list) }
        end
      end
    end
  end
end
