# frozen_string_literal: true

module Resque
  module Plugins
    module JobHistory
      # JobHistory cleanup functions to allow the user to cleanup Redis for histories.
      class HistoryList < HistoryDetails
        attr_accessor :list_name

        def initialize(class_name, list_name, list_maximum = nil)
          super(class_name)

          @list_name    = list_name
          @list_maximum = list_maximum
        end

        def add_job(job_id, class_name)
          add_to_job_history

          job_count = redis.lpush(job_list_key, job_id)
          save_class_information(job_id, class_name)
          redis.incr(total_jobs_key)

          delete_old_jobs(job_count)
        end

        def remove_job(job_id)
          redis.lrem(job_list_key, 0, job_id)
          remove_job_data(job_id)
        end

        def paged_jobs(page_num = 1, job_page_size = nil)
          job_page_size ||= page_size
          job_page_size = job_page_size.to_i
          job_page_size = Resque::Plugins::JobHistory::PAGE_SIZE if job_page_size < 1
          start         = (page_num - 1) * job_page_size
          start         = 0 if start >= num_jobs || start.negative?

          jobs(start, start + job_page_size - 1)
        end

        def jobs(start = 0, stop = -1)
          job_ids(start, stop).map do |job_id|
            Resque::Plugins::JobHistory::Job.new(job_class(job_id), job_id)
          end
        end

        def job_ids(start = 0, stop = -1)
          redis.lrange(job_list_key, start, stop)
        end

        def num_jobs
          redis.llen(job_list_key)
        end

        def total
          redis.get(total_jobs_key).to_i
        end

        def latest_job
          job_id = redis.lrange(job_list_key, 0, 0).first

          Resque::Plugins::JobHistory::Job.new(job_class(job_id), job_id) if job_id
        end

        def includes_job?(job_id)
          job_ids.include?(job_id)
        end

        def job_classes_key
          "#{job_history_base_key}.#{list_name}_job_classes"
        end

        private

        def add_to_job_history
          return if class_name.blank?

          redis.sadd(Resque::Plugins::JobHistory::HistoryDetails.job_history_key, class_name)
        end

        def max_jobs
          @list_maximum ||= class_history_len
          @list_maximum = 0 if @list_maximum.negative?
          @list_maximum
        end

        def delete_old_jobs(job_count)
          while num_jobs > max_jobs
            job_id         = redis.rpop(job_list_key)
            job_class_name = job_class(job_id)

            remove_job_data(job_id)

            Resque::Plugins::JobHistory::Job.new(job_class_name, job_id).safe_purge

            job_count -= 1
          end

          job_count
        end

        def total_jobs_key
          "#{job_history_base_key}.total_#{list_name}_jobs"
        end

        def job_list_key
          "#{job_history_base_key}.#{list_name}_jobs"
        end

        def job_class(job_id)
          redis.hget(job_classes_key, job_id) || class_name
        end

        def save_class_information(job_id, job_class_name)
          return unless class_name.blank? || job_class_name != class_name

          redis.hset job_classes_key, job_id, job_class_name
        end

        def remove_job_data(job_id)
          redis.hdel(job_classes_key, job_id)
        end
      end
    end
  end
end
