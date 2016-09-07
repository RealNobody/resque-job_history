require "active_support/concern"

module Resque
  module Plugins
    # Include in a Resque Job to keep a history of the execution of the job.
    # Every job keeps its own independent history so that you can see when an individual job was run.
    module JobHistory
      extend ActiveSupport::Concern

      include Resque::Plugins::JobHistory::Cleaner

      # Redis mapp:
      #   job_history - a set of all of the class names of all jobs
      #   job_history.<class_name>.max_jobs - The maximum number of jobs that have run for this class.
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
      NAME_SPACE      = "Resque::Plugins::ResqueJobHistory".freeze

      # class methods added to the included class.
      module ClassMethods
        def redis
          @redis ||= Redis::Namespace.new(NAME_SPACE, redis: Resque.redis)
        end

        module_function :redis

        def job_history_key
          "job_history"
        end

        module_function :job_history_key

        def job_history_base_key(class_name)
          class_name ||= name
          "#{job_history_key}.#{class_name}"
        end

        module_function :job_history_base_key

        def job_history_job_key(job_id, class_name)
          "#{job_history_base_key(class_name)}.#{job_id}"
        end

        module_function :job_history_job_key

        def max_jobs_running_key(class_name)
          "#{job_history_base_key(class_name)}.max_jobs"
        end

        module_function :max_jobs_running_key

        def total_finished_jobs_key(class_name)
          "#{job_history_base_key(class_name)}.total_finished_jobs"
        end

        module_function :total_finished_jobs_key

        def job_history_running_job_list_key(class_name)
          "#{job_history_base_key(class_name)}.running_jobs"
        end

        module_function :job_history_running_job_list_key

        def job_history_finished_job_list_key(class_name)
          "#{job_history_base_key(class_name)}.finished_jobs"
        end

        module_function :job_history_finished_job_list_key

        def encode_args(*args)
          Resque.encode(args)
        end

        module_function :encode_args

        def decode_args(args_string)
          Resque.decode(args_string)
        end

        module_function :decode_args

        def cancel_job(job_id, class_name)
          redis.hset(job_history_job_key(job_id, class_name),
                     "error",
                     "Unknown - Job failed to signal ending after the configured purge time or "\
                       "was canceled manually.")

          job_finished(job_id, class_name)
        end

        module_function :cancel_job

        def job_finished(job_id, class_name)
          redis.lrem job_history_running_job_list_key(class_name), 0, job_id

          record_job_finished(job_id, class_name)
          num_jobs = add_to_finished_list(job_id, class_name)

          delete_old_jobs(num_jobs, class_name)
        end

        module_function :job_finished

        def class_name_valid?(class_name)
          class_name.constantize
          true
        rescue StandardError
          false
        end

        module_function :class_name_valid?

        def retry_job(job_id, class_name)
          job = Resque::Plugins::JobHistory::JobViewer::ClassMethods.job_details(job_id, class_name)

          Resque.enqueue class_name, *decode_args(job[:args])
        end

        module_function :retry_job

        private

        def record_job_finished(job_id, class_name)
          redis.hset(job_history_job_key(job_id, class_name), "end_time", Time.now.utc.to_s)
          redis.incr(total_finished_jobs_key(class_name))
        end

        module_function :record_job_finished

        def add_to_finished_list(job_id, class_name)
          redis.lpush(job_history_finished_job_list_key(class_name), job_id)
        end

        module_function :add_to_finished_list

        def delete_old_jobs(num_jobs, class_name)
          while num_jobs > class_history_len(class_name)
            Resque::Plugins::JobHistory::Cleaner::ClassMethods.purge_job(redis.
                rpop(job_history_finished_job_list_key(class_name)), class_name)

            num_jobs -= 1
          end
        end

        module_function :delete_old_jobs

        def class_history_len(class_name)
          class_name.constantize.job_history_len
        rescue StandardError
          MAX_JOB_HISTORY
        end

        module_function :class_history_len
      end

      def job_history_len
        @job_history_len || MAX_JOB_HISTORY
      end

      def on_failure_job_history(exception, *_args)
        history_klass.redis.hset(job_key, "error", exception.message)

        history_klass.job_finished job_history_run_id, self.class.name
      end

      def before_perform_job_history(*args)
        @job_history_run_id = SecureRandom.uuid

        history_klass.redis.sadd(history_klass.job_history_key, self.class.name)
        start_job(*args)
      end

      def after_perform_job_history(*_args)
        history_klass.job_finished job_history_run_id, self.class.name
      end

      private

      def history_klass
        Resque::Plugins::JobHistory::ClassMethods
      end

      def cleaner_klass
        Resque::Plugins::JobHistory::Cleaner::ClassMethods
      end

      attr_reader :job_history_run_id

      def job_key(job_id = nil)
        job_id ||= job_history_run_id
        history_klass.job_history_job_key(job_id, self.class.name)
      end

      def start_job(*args)
        num_jobs = history_klass.redis.
            lpush(history_klass.job_history_running_job_list_key(self.class.name), job_history_run_id)

        record_num_jobs(num_jobs)

        record_job_start(*args)
      end

      def record_job_start(*args)
        history_klass.redis.hset(job_key, "start_time", Time.now.utc.to_s)
        history_klass.redis.hset(job_key, "args", history_klass.encode_args(*args))
      end

      def record_num_jobs(num_jobs)
        redis = history_klass.redis

        if redis.get(max_running_key).to_i < num_jobs
          redis.set(max_running_key, num_jobs)
        end

        return unless num_jobs > job_history_len

        cleaner_klass.clean_old_running_jobs(self.class.name)
      end

      def max_running_key
        history_klass.max_jobs_running_key(self.class.name)
      end

      def total_finished_key
        history_klass.total_finished_jobs_key(self.class.name)
      end

      def purge_age
        (@purge_jobs_after || 24.hours).ago
      end
    end
  end
end
