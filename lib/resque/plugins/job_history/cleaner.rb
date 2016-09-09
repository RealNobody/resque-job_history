module Resque
  module Plugins
    module JobHistory
      # JobHistory cleanup functions to allow the user to cleanup Redis for histories.
      class Cleaner
        class << self
          def clean_all_old_running_jobs
            job_classes.each do |class_name|
              Resque::Plugins::JobHistory::Job.new(class_name, "").clean_old_running_jobs
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
              del_key(stranded_key, "Stranded job key deleted")
            end
          end

          def purge_all_jobs
            job_classes.each do |class_name|
              purge_class class_name
            end

            del_key(Resque::Plugins::JobHistory::HistoryBase.new("").job_history_key,
                    "Purging job_history_key")
          end

          def purge_invalid_jobs
            viewer_klass.job_classes.each do |class_name|
              next if Resque::Plugins::JobHistory::HistoryBase.new(class_name).class_name_valid?

              purge_class(class_name)
            end
          end

          def purge_class(class_name)
            job_keys(class_name).each do |job_key|
              del_key(job_key, "Purging job key")
            end

            job_support_keys(class_name).each do |support_key|
              del_key(support_key, "Purging #{support_key}")
            end
          end

          private

          def job_classes
            Resque::Plugins::JobHistory::JobList.new.job_classes
          end

          def job_keys(class_name)
            history_base = Resque::Plugins::JobHistory::HistoryBase.new(class_name)

            history_base.redis.keys("#{history_base.job_history_base_key}.*") - job_support_keys(history_base)
          end

          def job_support_keys(history_base)
            if history_base.is_a?(String)
              history_base = Resque::Plugins::JobHistory::HistoryBase.new(history_base)
            end

            ["#{history_base.job_history_base_key}.running_jobs",
             "#{history_base.job_history_base_key}.total_running_jobs",
             "#{history_base.job_history_base_key}.finished_jobs",
             "#{history_base.job_history_base_key}.total_finished_jobs",
             "#{history_base.job_history_base_key}.max_jobs"]
          end

          def redis
            @redis ||= Resque::Plugins::JobHistory::HistoryBase.new("").redis
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
