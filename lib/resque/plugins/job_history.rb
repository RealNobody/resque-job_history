# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/numeric/time"

module Resque
  module Plugins
    # Include in a Resque Job to keep a history of the execution of the job.
    # Every job keeps its own independent history so that you can see when an individual job was run.
    module JobHistory
      extend ActiveSupport::Concern

      # Redis map:
      #   job_history - a set of all of the class names of all jobs
      #   job_history..linear_jobs - a list of the IDs for all jobs that have run in the order
      #                                          they were started.
      #   job_history..total_linear_jobs - The total number of jobs added to the linear list.
      #   job_history..linear_job_classes - The total number of jobs added to the linear list.
      #   job_history.<class_name>.max_jobs - The maximum number of jobs that have run concurrently
      #                                       for this class.
      #   job_history.<class_name>.total_failed_jobs - The total number of jobs that have failed.
      #   job_history.<class_name>.total_running_jobs - The total number of jobs that have been run.
      #   job_history.<class_name>.total_finished_jobs - The maximum number of jobs that have run for
      #                                                  this class.
      #   job_history.<class_name>.running_jobs - a list of the IDs for all running jobs in the order
      #                                          they were started.
      #   job_history.<class_name>.finished_jobs - a list of rhe IDs for all finished jobs in the
      #                                           order they completed.
      #   job_history.<class_name>.<job_id> - a hash of values detailing the job
      #     start_time
      #     args - JSON encoded array of encoded args
      #     end_time
      #     error
      MAX_JOB_HISTORY = 200
      PAGE_SIZE       = 25
      PURGE_AGE       = 24.hours

      # The class methods added to the job class that is being enqueued and whose history is to be
      # recorded.
      module ClassMethods
        def on_failure_job_history(error, *args)
          job_class_name = active_job_class_name(*args)
          job_args       = *active_job_args(*args)

          failed_job = find_failed_job(job_args, job_class_name)

          return unless failed_job
          return if failed_job.finished? && failed_job.error.present?

          failed_job.failed(error)
        end

        def around_perform_job_history(*args)
          start_time           = Time.now
          running_job          = Resque::Plugins::JobHistory::Job.new(active_job_class_name(*args), SecureRandom.uuid)
          self.most_recent_job = running_job

          begin
            running_job.start(*active_job_args(*args))

            yield if block_given?

            running_job.finish(start_time, *args)
          rescue StandardError => exception
            running_job.failed exception, start_time, *args
            raise
          ensure
            running_job.cancel(" Job did not signal completion on finish.", start_time, *args) unless running_job.finished? || running_job.error
            self.most_recent_job = nil
          end
        end

        def job_history_len
          @job_history_len ||= Resque::Plugins::JobHistory::MAX_JOB_HISTORY
        end

        def purge_age
          @purge_jobs_after ||= Resque::Plugins::JobHistory::PURGE_AGE
        end

        def page_size
          @page_size ||= Resque::Plugins::JobHistory::PAGE_SIZE
        end

        def exclude_from_linear_history
          @exclude_from_linear_history ||= false
        end

        def job_history
          Resque::Plugins::JobHistory::HistoryDetails.new(name)
        end

        def most_recent_job=(job)
          @most_recent_job = job
        end

        def most_recent_job
          @most_recent_job
        end

        private

        def active_job_class_name(*args)
          if Object.const_defined?("ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper") &&
              self >= "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper".constantize
            args[-1]["job_class"]
          else
            name
          end
        end

        def active_job_args(*args)
          if Object.const_defined?("ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper") &&
              self >= "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper".constantize
            args[-1]["arguments"]
          else
            args
          end
        end

        def find_failed_job(job_args, job_class_name)
          recent_job = most_recent_job

          if recent_job&.class_name == job_class_name && recent_job&.args == job_args
            recent_job
          else
            running_list  = HistoryList.new(job_class_name, "running")
            possible_jobs = running_list.jobs.select { |job| job.args == job_args }

            possible_jobs.length == 1 ? possible_jobs.first : nil
          end
        end
      end
    end
  end
end

if Object.const_defined?("ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper")
  unless "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper".constantize.included_modules.include? Resque::Plugins::JobHistory
    "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper".constantize.include Resque::Plugins::JobHistory
  end
end
