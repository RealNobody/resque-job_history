# frozen_string_literal: true

module Resque
  module Plugins
    module JobHistory
      # JobHistory cleanup functions to allow the user to cleanup Redis for histories.
      class Cleaner
        class << self
          def clean_all_old_running_jobs
            job_classes.each do |class_name|
              Resque::Plugins::JobHistory::HistoryDetails.new(class_name).clean_old_running_jobs
            end
          end

          def fixup_all_keys
            job_classes.each do |class_name|
              fixup_job_keys class_name
            end
          end

          def fixup_job_keys(class_name)
            keys = job_keys(class_name)
            keys -= Resque::Plugins::JobHistory::HistoryList.new(class_name, "running").job_ids
            keys -= Resque::Plugins::JobHistory::HistoryList.new(class_name, "finished").job_ids

            keys.each do |stranded_key|
              Resque::Plugins::JobHistory::Job.new(class_name, stranded_key).purge
              del_key(stranded_key, "Stranded job key deleted")
            end
          end

          def purge_all_jobs
            job_classes.each do |class_name|
              purge_class class_name
            end

            del_key(Resque::Plugins::JobHistory::HistoryDetails.job_history_key, "Purging job_history_key")

            redis.keys("*").each do |key|
              del_key(key, "Purging unknown key")
            end
          end

          def purge_invalid_jobs
            job_classes.each do |class_name|
              next if Resque::Plugins::JobHistory::HistoryDetails.new(class_name).class_name_valid?

              purge_class(class_name)
            end
          end

          def purge_class(class_name)
            return if similar_name?(class_name)

            class_keys(class_name).each do |job_key|
              del_key(job_key, "Purging job key")
            end
          end

          def similar_name?(class_name)
            job_classes.any? do |job_name|
              job_name != class_name && job_name[0..class_name.length - 1] == class_name
            end
          end

          private

          def job_classes
            Resque::Plugins::JobHistory::JobList.new.job_classes.sort.reverse
          end

          def class_keys(class_name)
            history_base = Resque::Plugins::JobHistory::HistoryDetails.new(class_name)

            history_base.redis.keys("#{history_base.job_history_base_key}*")
          end

          def job_keys(class_name)
            history_base = Resque::Plugins::JobHistory::HistoryDetails.new(class_name)

            history_base.redis.keys("#{history_base.job_history_base_key}.*") - job_support_keys(history_base)
          end

          def job_support_keys(history_base)
            ["#{history_base.job_history_base_key}.running_jobs",
             "#{history_base.job_history_base_key}.total_running_jobs",
             "#{history_base.job_history_base_key}.finished_jobs",
             "#{history_base.job_history_base_key}.total_finished_jobs",
             "#{history_base.job_history_base_key}.max_jobs",
             "#{history_base.job_history_base_key}.total_failed"]
          end

          def redis
            @redis ||= Resque::Plugins::JobHistory::HistoryDetails.new("").redis
          end

          def del_key(key, message)
            Resque.logger.warn("#{message} - #{key}")
            redis.del key
          end
        end
      end
    end
  end
end
