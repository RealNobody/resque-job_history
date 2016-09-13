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
        def around_perform_job_history(*args)
          running_job = Resque::Plugins::JobHistory::Job.new(name, SecureRandom.uuid)

          begin
            running_job.start(*args)

            yield if block_given?

            running_job.finish
          rescue StandardError => exception
            running_job.failed exception
            raise
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
      end
    end
  end
end
