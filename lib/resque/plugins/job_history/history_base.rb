module Resque
  module Plugins
    module JobHistory
      # A base class for job history classes which provides a base key and a few common functions.
      class HistoryBase
        attr_accessor :class_name

        NAME_SPACE = "Resque::Plugins::ResqueJobHistory".freeze
        PAGE_SIZE  = 25

        def initialize(class_name)
          @class_name = class_name
        end

        def redis
          @redis ||= Redis::Namespace.new(NAME_SPACE, redis: Resque.redis)
        end

        def job_history_key
          "job_history"
        end

        def job_history_base_key
          "#{job_history_key}.#{class_name}"
        end

        def running_list
          @running_list = HistoryList.new(class_name, "running")
        end

        def finished_list
          @finished_list = HistoryList.new(class_name, "finished")
        end

        def class_name_valid?
          described_class.present?
        end

        private

        def described_class
          class_name.constantize
        rescue StandardError
          nil
        end

        def class_purge_age
          described_class.try(:purge_age) || 24.hours
        end

        def class_history_len
          described_class.try(:job_history_len) || MAX_JOB_HISTORY
        end

        def class_page_size
          described_class.try(:page_size) || Resque::Plugins::JobHistory::HistoryBase::PAGE_SIZE
        end
      end
    end
  end
end
