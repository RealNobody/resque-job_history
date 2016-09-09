module Resque
  module Plugins
    module JobHistory
      # a class encompassing a single job.
      class Job < HistoryBase
        attr_accessor :job_id

        def initialize(class_name, job_id)
          super(class_name)

          @job_id = job_id
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
          error.blank?
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
          num_jobs = running_list.add_job(job_id)

          record_num_jobs(num_jobs)
          record_job_start(*args)
        end

        def finish
          redis.hset(job_key, "end_time", Time.now.utc.to_s)

          finished_list.add_job(job_id)
          running_list.remove_job(job_id)
        end

        def failed(exception)
          redis.hset(job_key, "error", exception.message)

          finish
        end

        def cancel
          redis.hset(job_key,
                     "error",
                     "Unknown - Job failed to signal ending after the configured purge time or "\
                       "was canceled manually.")

          finish
        end

        def retry
          return unless described_class

          Resque.enqueue described_class, *args
        end

        def purge
          running_list.remove_job(job_id)
          finished_list.remove_job(job_id)

          redis.del(job_key)
        end

        def max_jobs
          redis.get(max_running_key).to_i
        end

        private

        def record_job_start(*args)
          redis.hset(job_key, "start_time", Time.now.utc.to_s)
          redis.hset(job_key, "args", encode_args(*args))
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

          return unless num_jobs > class_history_len

          clean_old_running_jobs
        end

        def max_running_key
          "#{job_history_base_key}.max_jobs"
        end

        def clean_old_running_jobs
          too_old_time = class_purge_age.ago

          running_list.jobs.each do |job|
            job_start = job.start_time

            if job_start.blank? || job_start.to_time < too_old_time
              job.start(*job.args) if job_start.blank?
              job.cancel
            end
          end
        end
      end
    end
  end
end
