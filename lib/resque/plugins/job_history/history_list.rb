# frozen_string_literal: true

module Resque
  module Plugins
    module JobHistory
      # JobHistory cleanup functions to allow the user to cleanup Redis for histories.
      class HistoryList < HistoryDetails
        attr_accessor :list_name

        def initialize(class_name, list_name)
          super(class_name)

          @list_name = list_name
        end

        def add_job(job_id)
          add_to_history

          job_count = redis.lpush(job_list_key, job_id)
          redis.incr(total_jobs_key)

          delete_old_jobs(job_count)
        end

        def remove_job(job_id)
          redis.lrem(job_list_key, 0, job_id)
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
            Resque::Plugins::JobHistory::Job.new(class_name, job_id)
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

          Resque::Plugins::JobHistory::Job.new(class_name, job_id) if job_id
        end

        private

        def add_to_history
          redis.sadd(Resque::Plugins::JobHistory::HistoryDetails.job_history_key, class_name)
        end

        def delete_old_jobs(job_count)
          max_jobs = class_history_len

          while job_count > max_jobs
            Resque::Plugins::JobHistory::Job.new(class_name, redis.rpop(job_list_key)).purge

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
      end
    end
  end
end
