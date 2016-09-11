# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/numeric/time"

module Resque
  module Plugins
    # Include in a Resque Job to keep a history of the execution of the job.
    # Every job keeps its own independent history so that you can see when an individual job was run.
    module JobHistory
      extend ActiveSupport::Concern

      # Redis mapp:
      #   job_history - a set of all of the class names of all jobs
      #   job_history.<class_name>.max_jobs - The maximum number of jobs that have run concurrently
      #                                       for this class.
      #   job_history.<class_name>.total_failed_jobs - The total number of jobs that have failed
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
        attr_reader :running_job

        def before_perform_job_history(*args)
          running_job.cancel if running_job

          @running_job = Resque::Plugins::JobHistory::Job.new(name, SecureRandom.uuid)

          running_job.start(*args)
        end

        def after_perform_job_history(*_args)
          running_job.try(:finish)
          @running_job = nil
        end

        def on_failure_job_history(exception, *_args)
          running_job.try(:failed, exception)
          @running_job = nil
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

        def job_history
          Resque::Plugins::JobHistory::HistoryDetails.new(name)
        end
      end
    end
  end
end
