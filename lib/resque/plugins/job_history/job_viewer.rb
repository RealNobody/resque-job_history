require "active_support/concern"

module Resque
  module Plugins
    module JobHistory
      # JobHistory cleanup functions to allow the user to cleanup Redis for histories.
      module JobViewer
        extend ActiveSupport::Concern

        # class methods added to the included class.
        module ClassMethods
          def job_classes
            history_klass.redis.smembers(history_klass.job_history_key)
          end

          module_function :job_classes

          def latest_job(class_name)
            job_id = history_klass.redis.
                lrange(history_klass.job_history_running_job_list_key(class_name), -1, -1).first ||
                history_klass.redis.
                    lrange(history_klass.job_history_finished_job_list_key(class_name), -1, -1).first

            Resque::Plugins::JobHistory::JobViewer::ClassMethods.job_details(job_id, class_name)
          end

          module_function :latest_job

          def running_job_list(class_name)
            history_klass.redis.lrange(history_klass.job_history_running_job_list_key(class_name), 0, -1)
          end

          module_function :running_job_list

          def finished_job_list(class_name)
            history_klass.redis.lrange(history_klass.job_history_finished_job_list_key(class_name), 0, -1)
          end

          module_function :finished_job_list

          def job_summaries(sort_key)
            sort_key ||= :class_name

            job_classes.map { |class_name| job_class_summary(class_name) }.sort_by do |element|
              summary_sort_value(element, sort_key)
            end
          end

          module_function :job_summaries

          def running_jobs(class_name)
            running_job_list(class_name).map do |job_id|
              job_details(job_id, class_name)
            end
          end

          module_function :running_jobs

          def finished_jobs(class_name)
            finished_job_list(class_name).map do |job_id|
              job_details(job_id, class_name)
            end
          end

          module_function :finished_jobs

          def job_class_summary(class_name)
            redis = history_klass.redis

            { class_name:          class_name,
              running_jobs:        num_running_jobs(class_name, redis),
              finished_jobs:       num_finsished_jobs(class_name, redis),
              total_finished_jobs: total_finished_jobs(class_name, redis),
              max_running_jobs:    max_jobs_running(class_name, redis),
              last_run:            latest_job(class_name) }
          end

          module_function :job_class_summary

          def job_details(job_id, class_name)
            details              = history_klass.redis.
                hgetall(history_klass.job_history_job_key(job_id, class_name)).with_indifferent_access
            details[:start_time] = details[:start_time].to_time if details[:start_time]
            details[:end_time]   = details[:end_time].to_time if details[:end_time]
            details[:job_id]     = job_id
            details[:class_name] = class_name

            details
          end

          module_function :job_details

          private

          def history_klass
            Resque::Plugins::JobHistory::ClassMethods
          end

          module_function :history_klass

          def max_jobs_running(class_name, redis)
            redis.get(history_klass.max_jobs_running_key(class_name))
          end

          module_function :max_jobs_running

          def total_finished_jobs(class_name, redis)
            redis.get(history_klass.total_finished_jobs_key(class_name))
          end

          module_function :total_finished_jobs

          def num_finsished_jobs(class_name, redis)
            redis.llen(history_klass.job_history_finished_job_list_key(class_name))
          end

          module_function :num_finsished_jobs

          def num_running_jobs(class_name, redis)
            redis.llen(history_klass.job_history_running_job_list_key(class_name))
          end

          module_function :num_running_jobs

          def summary_sort_value(job_summary, sort_key)
            case sort_key.to_sym
              when :class_name, :running_jobs, :total_finished_jobs, :max_running_jobs
                job_summary[sort_key.to_sym]
              when :start_time
                job_summary[:last_run][:start_time]
              when :durration
                (job_summary[:last_run][:end_time] || Time.now) - job_summary[:last_run][:start_time]
              when :success
                job_summary[:error].present?
            end
          end

          module_function :summary_sort_value
        end
      end
    end
  end
end
