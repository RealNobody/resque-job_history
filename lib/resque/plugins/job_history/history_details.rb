# frozen_string_literal: true

module Resque
  module Plugins
    module JobHistory
      # A base class for job history classes which provides a base key and a few common functions.
      class HistoryDetails
        attr_accessor :class_name

        NAME_SPACE = "Resque::Plugins::ResqueJobHistory"

        class << self
          def job_history_key
            "job_history"
          end
        end

        def initialize(class_name)
          @class_name = class_name
        end

        def redis
          @redis ||= Redis::Namespace.new(NAME_SPACE, redis: Resque.redis)
        end

        def job_history_base_key
          "#{Resque::Plugins::JobHistory::HistoryDetails.job_history_key}.#{class_name}"
        end

        def running_jobs
          @running_list ||= HistoryList.new(class_name, "running")
        end

        def finished_jobs
          @finished_list ||= HistoryList.new(class_name, "finished")
        end

        def max_concurrent_jobs
          redis.get(max_running_key).to_i
        end

        def total_failed_jobs
          redis.get(total_failed_key).to_i
        end

        def class_name_valid?
          described_class.present?
        end

        def clean_old_running_jobs
          too_old_time = class_purge_age.ago

          running_jobs.jobs.each do |job|
            job_start = job.start_time

            if job_start.blank? || job_start.to_time < too_old_time
              job.start(*job.args) if job_start.blank?
              job.cancel
            end
          end
        end

        private

        def described_class
          class_name.constantize
        rescue StandardError
          nil
        end

        def class_purge_age
          described_class.try(:purge_age) || 24.hours
        end

        def class_history_len
          described_class.try(:job_history_len) || MAX_JOB_HISTORY
        end

        def class_page_size
          described_class.try(:page_size) || Resque::Plugins::JobHistory::PAGE_SIZE
        end

        def total_failed_key
          "#{job_history_base_key}.total_failed"
        end

        def max_running_key
          "#{job_history_base_key}.max_jobs"
        end
      end
    end
  end
end
