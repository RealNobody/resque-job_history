# frozen_string_literal: true

module Resque
  module Plugins
    module JobHistory
      # a class encompassing a single job.
      class Job < HistoryDetails
        attr_accessor :job_id

        def initialize(class_name, job_id)
          super(class_name)

          @stored_values = nil
          @job_id        = job_id
        end

        def job_key
          "#{job_history_base_key}.#{job_id}"
        end

        def start_time
          stored_values[:start_time].try(:to_time)
        end

        def finished?
          stored_values[:end_time].present?
        end

        def succeeded?
          finished? && error.blank?
        end

        def duration
          (end_time || Time.now) - start_time
        end

        def end_time
          stored_values[:end_time].try(:to_time)
        end

        def args
          decode_args(stored_values[:args])
        end

        def error
          stored_values[:error]
        end

        def start(*args)
          num_jobs = running_jobs.add_job(job_id)

          record_job_start(*args)
          record_num_jobs(num_jobs)
        end

        def finish
          redis.hset(job_key, "end_time", Time.now.utc.to_s)

          finished_jobs.add_job(job_id)
          running_jobs.remove_job(job_id)

          reset
        end

        def failed(exception)
          redis.hset(job_key, "error", exception.message)
          redis.incr(total_failed_key)

          finish
        end

        def cancel
          redis.hset(job_key,
                     "error",
                     "Unknown - Job failed to signal ending after the configured purge time or "\
                       "was canceled manually.")
          redis.incr(total_failed_key)

          finish
        end

        def retry
          return unless described_class

          Resque.enqueue described_class, *args
        end

        def purge
          # To keep the counts honest...
          cancel unless finished?

          running_jobs.remove_job(job_id)
          finished_jobs.remove_job(job_id)

          redis.del(job_key)

          reset
        end

        private

        def record_job_start(*args)
          redis.hset(job_key, "start_time", Time.now.utc.to_s)
          redis.hset(job_key, "args", encode_args(*args))

          reset
        end

        def stored_values
          unless @stored_values
            @stored_values = redis.hgetall(job_key).with_indifferent_access
          end

          @stored_values
        end

        def encode_args(*args)
          Resque.encode(args)
        end

        def decode_args(args_string)
          Resque.decode(args_string)
        end

        def record_num_jobs(num_jobs)
          if redis.get(max_running_key).to_i < num_jobs
            redis.set(max_running_key, num_jobs)
          end

          return unless num_jobs >= class_history_len

          clean_old_running_jobs
        end

        def reset
          @stored_values = nil
        end
      end
    end
  end
end
