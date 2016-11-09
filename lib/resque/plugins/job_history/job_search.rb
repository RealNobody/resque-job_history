# frozen_string_literal: true
# rubocop:disable ClassLength

module Resque
  module Plugins
    module JobHistory
      # This class searches through jobs looking for one which matches the passed in criteria.
      class JobSearch
        ALL_ATTRIBUTES = [:search_type,
                          :job_class_name,
                          :search_for,
                          :regex_search,
                          :case_insensitive,
                          :last_class_name,
                          :last_job_id,
                          :last_job_group].freeze

        SEARCH_TYPES = %w(search_all search_job search_linear_history).freeze

        DEFAULT_SEARCH_TIMEOUT = 10.seconds

        attr_reader(*ALL_ATTRIBUTES)

        def initialize(params)
          params = params.with_indifferent_access
          ALL_ATTRIBUTES.each do |attribute|
            instance_variable_set("@#{attribute}", params[attribute]) if params.key?(attribute)
          end

          raise ArgumentError, "invalid search_type" unless SEARCH_TYPES.include?(search_type)
        end

        def retry_search_settings(all_settings)
          settings = search_settings(all_settings)

          [:last_class_name,
           :last_job_id,
           :last_job_group].each do |continue_setting|
            settings.delete(continue_setting)
          end

          settings
        end

        def search_settings(all_settings)
          settings = ALL_ATTRIBUTES.dup

          unless all_settings
            settings.delete :search_for
            settings.delete :regex_search
            settings.delete :case_insensitive
          end

          settings.each_with_object({}) do |setting, hash|
            hash[setting] = send(setting)

            hash.delete(setting) if hash[setting].blank?
          end
        end

        def search
          end_search?

          send search_type
        end

        def class_results
          @class_results ||= []
        end

        def run_results
          @run_results ||= []
        end

        def more_records?
          last_class_name || last_job_id
        end

        def search_timeout
          DEFAULT_SEARCH_TIMEOUT
        end

        private

        def search_end_time
          @search_end_time ||= search_timeout.from_now
        end

        def end_search?
          Time.now > search_end_time
        end

        def search_all
          job_list    = Resque::Plugins::JobHistory::JobList.new
          search_jobs = job_list.job_classes.sort.map { |class_name| job_list.job_details(class_name) }

          search_class_names(search_jobs) unless last_class_name && last_job_id

          return if end_search? && last_class_name.present? && !last_job_id

          search_all_class_jobs(search_jobs)
        end

        def search_all_class_jobs(search_jobs)
          search_jobs = remove_searched_job_classes(search_jobs)

          search_jobs.each do |job_class|
            search_job_class job_class

            @last_class_name = job_class.class_name

            break if end_search? && last_job_id.present?
          end

          @last_class_name = nil if search_jobs.blank? || !end_search? || last_job_id.blank?
        end

        def search_job
          job_class = Resque::Plugins::JobHistory::HistoryDetails.new(job_class_name)

          search_job_class(job_class)
        end

        def search_linear_history
          job_class = Resque::Plugins::JobHistory::JobList.new

          search_class_jobs(job_class.linear_jobs.jobs, :linear_jobs)
        end

        def search_regex
          @search_regex = if search_for.blank?
                            search_for
                          elsif regex_search
                            Regexp.new(search_for, case_insensitive)
                          elsif case_insensitive
                            search_for.downcase
                          else
                            search_for
                          end
        end

        def validate_string(value)
          if search_regex.blank?
            value == "[]"
          elsif regex_search
            value.match(search_regex)
          elsif case_insensitive
            value.downcase.include?(search_regex)
          else
            value.include?(search_regex)
          end
        end

        def search_class_names(search_jobs)
          search_jobs = remove_searched_job_classes(search_jobs)

          search_jobs.each do |job_class|
            class_results << job_class if validate_string(job_class.class_name)
            @last_class_name = job_class.class_name

            break if end_search?
          end

          @last_class_name = nil if search_jobs.blank? || !end_search?
        end

        def remove_searched_job_classes(search_jobs)
          last_index = if last_class_name.present?
                         job_index = search_jobs.
                             index { |job_class| job_class.class_name == last_class_name } ||
                             search_jobs.length

                         job_index += 1 if last_job_id.blank?

                         job_index
                       else
                         0
                       end

          if last_index.positive?
            Array.wrap(search_jobs[last_index..-1])
          else
            search_jobs
          end
        end

        def search_job_class(job_class)
          if last_job_group.blank? || last_job_group == :running_jobs
            search_class_jobs(job_class.running_jobs.jobs, :running_jobs)

            return unless !end_search? || last_job_id.blank?
          end

          search_class_jobs(job_class.finished_jobs.jobs, :finished_jobs)
        end

        def search_class_jobs(job_list, job_group)
          return if last_job_group.present? && last_job_group.to_s != job_group.to_s

          job_list = remove_searched_jobs(job_list, job_group)

          @last_job_group = job_group

          add_class_job_results(job_list)

          return if job_list.present? && end_search?

          @last_job_id    = nil
          @last_job_group = nil
        end

        def add_class_job_results(job_list)
          job_list.each do |job|
            run_results << job if validate_string(Resque.encode(job.args))
            @last_job_id = job.job_id

            break if end_search?
          end
        end

        def remove_searched_jobs(job_list, job_group)
          last_index = if last_job_id.present? && job_group == last_job_group
                         (job_list.index { |job_run| job_run.job_id == last_job_id } ||
                             job_list.length) + 1
                       else
                         0
                       end

          if last_index.positive?
            Array.wrap(job_list[last_index..-1])
          else
            job_list
          end
        end
      end
    end
  end
end
