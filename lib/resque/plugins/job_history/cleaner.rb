module Resque
  module Plugins
    module JobHistory
      # JobHistory cleanup functions to allow the user to cleanup Redis for histories.
      module Cleaner
        def clean_all_old_running_jobs
          viewer_klass.job_classes.each do |class_name|
            clean_old_running_jobs class_name
          end
        end

        module_function :clean_all_old_running_jobs

        def clean_old_running_jobs(class_name)
          job_list = viewer_klass.running_job_list(class_name)

          too_old_time = class_purge_age(class_name)

          job_list.each do |job_id|
            job_start = history_klass.redis.
                hget(history_klass.job_history_job_key(job_id, class_name), "start_time")

            if job_start.blank? || job_start.to_time < too_old_time
              cancel_job job_id, class_name
            end
          end
        end

        module_function :clean_old_running_jobs

        def fixup_job_keys(class_name)
          keys = job_keys(class_name)
          keys -= viewer_klass.running_job_list(class_name)
          keys -= history_klass.redis.
              lrange(history_klass.job_history_finished_job_list_key(class_name), 0, -1)

          keys.each do |stranded_key|
            del_key(stranded_key, "Stranded job key deleted")
          end
        end

        module_function :fixup_job_keys

        def fixup_all_keys
          viewer_klass.job_classes.each do |class_name|
            fixup_job_keys class_name
          end
        end

        module_function :fixup_all_keys

        def purge_class(class_name)
          purge_class_keys(class_name)
        end

        module_function :purge_class

        def purge_all_jobs
          viewer_klass.job_classes.each do |class_name|
            purge_class_keys class_name
          end

          del_key(history_klass.job_history_key, "Purging job_history_key")
        end

        module_function :purge_all_jobs

        def purge_invalid_jobs
          viewer_klass.job_classes.each do |class_name|
            next if history_klass.class_name_valid?(class_name)

            purge_class_keys(class_name)
          end
        end

        module_function :purge_invalid_jobs

        def purge_job(job_id, class_name)
          redis = history_klass.redis

          redis.lrem(history_klass.job_history_finished_job_list_key(class_name), 0, job_id)
          redis.lrem(history_klass.job_history_running_job_list_key(class_name), 0, job_id)

          history_klass.redis.del(history_klass.job_history_job_key(job_id, class_name))
        end

        module_function :purge_job

        private

        def history_klass
          Resque::Plugins::JobHistory
        end

        module_function :history_klass

        def viewer_klass
          Resque::Plugins::JobHistory::JobViewer
        end

        module_function :viewer_klass

        def class_purge_age(class_name)
          class_name.constantize.purge_age
        rescue StandardError
          24.hours.ago
        end

        module_function :class_purge_age

        def purge_class_keys(class_name)
          job_keys(class_name).each do |job_key|
            del_key(job_key, "Purging job key")
          end

          job_support_keys(class_name).each do |support_key|
            del_key(support_key, "Purging #{support_key}")
          end
        end

        module_function :purge_class_keys

        def del_key(key, message)
          Resque.logger.warn("#{message} - #{key}")
          history_klass.redis.del key
        end

        module_function :del_key

        def job_keys(class_name)
          history_klass.redis.
              keys("#{history_klass.job_history_base_key(class_name)}.*") - job_support_keys(class_name)
        end

        module_function :job_keys

        def job_support_keys(class_name)
          [history_klass.job_history_running_job_list_key(class_name),
           history_klass.job_history_finished_job_list_key(class_name),
           history_klass.max_jobs_running_key(class_name)]
        end

        module_function :job_support_keys
      end
    end
  end
end
