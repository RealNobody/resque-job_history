# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::JobHistory::JobSearch do
  let(:test_jobs) { [CustomPageSizeJob, BasicJob] }
  let(:find_regex) { "Cust.*Job" }
  let(:regex_case_sensitive_val) { "Big fuzzy Custard Jobs are awesome" }
  let(:regex_case_insensitive_val) { "this is a job for custard jobs!  Up Up and Away!" }
  let(:find_string) { "CustomP" }
  let(:string_case_sensitive_val) { "Have you ever met the CustomPeople?  I have." }
  let(:string_case_insensitive_val) { "What abou the custompeople though?" }
  let!(:jobs) do
    test_jobs.map do |job_class|
      [Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
          start(regex_case_sensitive_val).finish,
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start((Faker::Lorem.words(5) + [regex_case_insensitive_val]).sample(100)),
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start(something_else: "fred", value: string_case_sensitive_val, not_value: "harold"),
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start(string_case_insensitive_val).failed(StandardError.new("failed")),
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start.finish]
    end
  end

  describe "unknown search" do
    it "raises an exception if the search_type is unknown" do
      expect { Resque::Plugins::JobHistory::JobSearch.new(search_type: "fred") }.
          to raise_error ArgumentError
    end
  end

  describe "search_all" do
    describe "class name search" do
      it "does not match empty search" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type: "search_all", search_for: "")

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 2
      end

      describe "regex" do
        it "matches case sensitive" do
          search = Resque::Plugins::JobHistory::JobSearch.new(search_type:  "search_all",
                                                              search_for:   find_regex,
                                                              regex_search: true)

          search.search

          expect(search.class_results.length).to eq 1
          expect(search.class_results.first.class_name).to eq "CustomPageSizeJob"
        end

        it "matches case insensitive" do
          search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_all",
                                                              search_for:       find_regex.downcase,
                                                              regex_search:     true,
                                                              case_insensitive: true)

          search.search

          expect(search.class_results.length).to eq 1
          expect(search.class_results.first.class_name).to eq "CustomPageSizeJob"
        end
      end

      describe "no regex" do
        it "matches case sensitive" do
          search = Resque::Plugins::JobHistory::JobSearch.new(search_type:  "search_all",
                                                              search_for:   find_string,
                                                              regex_search: false)

          search.search

          expect(search.class_results.length).to eq 1
          expect(search.class_results.first.class_name).to eq "CustomPageSizeJob"
        end

        it "matches case insensitive" do
          search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_all",
                                                              search_for:       find_string.upcase,
                                                              regex_search:     false,
                                                              case_insensitive: true)

          search.search

          expect(search.class_results.length).to eq 1
          expect(search.class_results.first.class_name).to eq "CustomPageSizeJob"
        end
      end
    end

    it "returns both class name and job class results" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_all",
                                                          search_for:       find_regex.downcase,
                                                          regex_search:     true,
                                                          case_insensitive: true)

      search.search

      expect(search.class_results.length).to be >= 1
      expect(search.run_results.length).to be >= 1
    end
  end

  describe "search_job" do
    it "searches running and finished jobs" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_job",
                                                          job_class_name:   "CustomPageSizeJob",
                                                          search_for:       find_regex.downcase,
                                                          regex_search:     true,
                                                          case_insensitive: true)

      search.search

      expect(search.class_results).to be_blank
      expect(search.run_results.length).to eq 2
      expect(search.run_results.first.finished?).not_to eq search.run_results.last.finished?
    end

    it "searches failed jobs" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_job",
                                                          job_class_name:   "CustomPageSizeJob",
                                                          search_for:       find_string.downcase,
                                                          regex_search:     false,
                                                          case_insensitive: true)

      search.search

      expect(search.class_results).to be_blank
      expect(search.run_results.length).to eq 2
      expect(search.run_results.last.succeeded?).to be_falsey
    end

    it "searches for empty arguments" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:    "search_job",
                                                          job_class_name: "CustomPageSizeJob",
                                                          search_for:     "",
                                                          regex_search:   true)

      search.search

      expect(search.class_results).to be_blank
      expect(search.run_results.length).to eq 1
    end

    describe "regex" do
      it "matches case sensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:    "search_job",
                                                            job_class_name: "CustomPageSizeJob",
                                                            search_for:     find_regex,
                                                            regex_search:   true)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 1
        expect(search.run_results.first.job_id).to eq jobs[0][0].job_id
      end

      it "matches case insensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_job",
                                                            job_class_name:   "CustomPageSizeJob",
                                                            search_for:       find_regex.downcase,
                                                            regex_search:     true,
                                                            case_insensitive: true)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 2
        expect(search.run_results.first.job_id).to eq jobs[0][1].job_id
        expect(search.run_results.last.job_id).to eq jobs[0][0].job_id
      end
    end

    describe "no regex" do
      it "matches case sensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:    "search_job",
                                                            job_class_name: "CustomPageSizeJob",
                                                            search_for:     find_string,
                                                            regex_search:   false)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 1
        expect(search.run_results.first.job_id).to eq jobs[0][2].job_id
      end

      it "matches case insensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_job",
                                                            job_class_name:   "CustomPageSizeJob",
                                                            search_for:       find_string.upcase,
                                                            regex_search:     false,
                                                            case_insensitive: true)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 2
        expect(search.run_results.first.job_id).to eq jobs[0][2].job_id
        expect(search.run_results.last.job_id).to eq jobs[0][3].job_id
      end
    end
  end

  describe "search_linear_history" do
    before(:each) do
      jobs.flatten.each do |job|
        job.running_jobs.remove_job(job.job_id)
        job.finished_jobs.remove_job(job.job_id)
      end
    end

    it "searches running and finished jobs" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_linear_history",
                                                          search_for:       find_regex.downcase,
                                                          regex_search:     true,
                                                          case_insensitive: true)

      search.search

      expect(search.class_results).to be_blank
      expect(search.run_results.length).to eq 4
    end

    it "searches failed jobs" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_linear_history",
                                                          search_for:       find_string.downcase,
                                                          regex_search:     false,
                                                          case_insensitive: true)

      search.search

      expect(search.class_results).to be_blank
      expect(search.run_results.length).to eq 4
    end

    it "searches for empty arguments" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:    "search_linear_history",
                                                          job_class_name: "CustomPageSizeJob",
                                                          search_for:     "",
                                                          regex_search:   true)

      search.search

      expect(search.class_results).to be_blank
      expect(search.run_results.length).to eq 2
    end

    describe "regex" do
      it "matches case sensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:    "search_linear_history",
                                                            job_class_name: "CustomPageSizeJob",
                                                            search_for:     find_regex,
                                                            regex_search:   true)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 2
        expect(search.run_results.first.job_id).to eq jobs[1][0].job_id
        expect(search.run_results.last.job_id).to eq jobs[0][0].job_id
      end

      it "matches case insensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_linear_history",
                                                            search_for:       find_regex.downcase,
                                                            regex_search:     true,
                                                            case_insensitive: true)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 4
        expect(search.run_results[0].job_id).to eq jobs[1][1].job_id
        expect(search.run_results[1].job_id).to eq jobs[1][0].job_id
        expect(search.run_results[2].job_id).to eq jobs[0][1].job_id
        expect(search.run_results[3].job_id).to eq jobs[0][0].job_id
      end
    end

    describe "no regex" do
      it "matches case sensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:    "search_linear_history",
                                                            job_class_name: "CustomPageSizeJob",
                                                            search_for:     find_string,
                                                            regex_search:   false)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 2
        expect(search.run_results.first.job_id).to eq jobs[1][2].job_id
        expect(search.run_results.last.job_id).to eq jobs[0][2].job_id
      end

      it "matches case insensitive" do
        search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_linear_history",
                                                            search_for:       find_string.upcase,
                                                            regex_search:     false,
                                                            case_insensitive: true)

        search.search

        expect(search.class_results).to be_blank
        expect(search.run_results.length).to eq 4
        expect(search.run_results[0].job_id).to eq jobs[1][3].job_id
        expect(search.run_results[1].job_id).to eq jobs[1][2].job_id
        expect(search.run_results[2].job_id).to eq jobs[0][3].job_id
        expect(search.run_results[3].job_id).to eq jobs[0][2].job_id
      end
    end
  end

  describe "search_settings" do
    let(:full_settings) do
      { search_type:      "search_job",
        job_class_name:   "CustomPageSizeJob",
        search_for:       "some string",
        regex_search:     true,
        case_insensitive: true,
        last_class_name:  "BasicJob",
        last_job_id:      "last job id",
        last_job_group:   "last group name" }
    end
    let(:nil_setting) do
      [:search_for,
       :regex_search,
       :case_insensitive,
       :job_class_name,
       :last_class_name,
       :last_job_id,
       :last_job_group].sample
    end
    let(:nilled_setting) do
      nilled = full_settings.dup
      nilled.delete(nil_setting)
      nilled
    end

    it "only returns non-nil settings" do
      search = Resque::Plugins::JobHistory::JobSearch.new(nilled_setting)

      return_value = search.search_settings(true)

      expect(return_value).not_to be_key(nil_setting)

      (full_settings.keys - [nil_setting]).each do |setting|
        expect(return_value).to be_key(setting)
      end
    end

    it "returns all settings" do
      search = Resque::Plugins::JobHistory::JobSearch.new(full_settings)

      return_value = search.search_settings(true)

      full_settings.keys.each do |setting|
        expect(return_value).to be_key(setting)
      end
    end

    it "returns partial settings" do
      search = Resque::Plugins::JobHistory::JobSearch.new(full_settings)

      return_value = search.search_settings(false)

      expect(return_value).not_to be_key(:search_for)
      expect(return_value).not_to be_key(:regex_search)
      expect(return_value).not_to be_key(:case_insensitive)
    end
  end

  describe "retry_search_settings" do
    let(:full_settings) do
      { search_type:      "search_job",
        job_class_name:   "CustomPageSizeJob",
        search_for:       "some string",
        regex_search:     true,
        case_insensitive: true,
        last_class_name:  "BasicJob",
        last_job_id:      "last job id",
        last_job_group:   "last group name" }
    end
    let(:exclude_settings) { [:last_class_name, :last_job_id, :last_job_group] }
    let(:nil_setting) do
      [:search_for,
       :regex_search,
       :case_insensitive,
       :job_class_name].sample
    end
    let(:nilled_setting) do
      nilled = full_settings.dup
      nilled.delete(nil_setting)
      nilled
    end

    it "only returns non-nil settings" do
      search = Resque::Plugins::JobHistory::JobSearch.new(nilled_setting)

      return_value = search.retry_search_settings(true)

      exclude_settings.each do |setting|
        expect(return_value).not_to be_key(setting)
      end

      (full_settings.keys - exclude_settings - [nil_setting]).each do |setting|
        expect(return_value).to be_key(setting)
      end
    end

    it "returns all settings" do
      search = Resque::Plugins::JobHistory::JobSearch.new(full_settings)

      return_value = search.retry_search_settings(true)

      exclude_settings.each do |setting|
        expect(return_value).not_to be_key(setting)
      end

      (full_settings.keys - exclude_settings).each do |setting|
        expect(return_value).to be_key(setting)
      end
    end

    it "returns partial settings" do
      search = Resque::Plugins::JobHistory::JobSearch.new(full_settings)

      return_value = search.retry_search_settings(false)

      expect(return_value).not_to be_key(:search_for)
      expect(return_value).not_to be_key(:regex_search)
      expect(return_value).not_to be_key(:case_insensitive)
    end
  end

  describe "timeout" do
    it "can stop then resume class name searches" do
      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_all",
                                                          search_for:       find_regex,
                                                          regex_search:     true,
                                                          case_insensitive: true)

      allow(search).to receive(:search_timeout).and_return(0.01.seconds)
      allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
        sleep(0.01)
        orig_function.call(*args)
      end

      search.search
      num_searches = 1

      expect(search.more_records?).to be_truthy

      while search.more_records?
        num_searches += 1

        search.search
      end

      # Once for every job class
      # Once for every job in each class
      # Once to verify that there are no more results.
      expect(num_searches).to eq jobs.flatten.length + test_jobs.length + 1

      expect(search.class_results.length).to eq 1
      expect(search.run_results.length).to eq 4

      expect(search.class_results.first.class_name).to eq "CustomPageSizeJob"

      # sorted by class name, then running, then finished.
      expect(search.run_results[0].job_id).to eq jobs[1][1].job_id
      expect(search.run_results[1].job_id).to eq jobs[1][0].job_id
      expect(search.run_results[2].job_id).to eq jobs[0][1].job_id
      expect(search.run_results[3].job_id).to eq jobs[0][0].job_id
    end

    it "can stop then resume class name searches with a new search each time" do
      class_results = []
      run_results   = []

      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_all",
                                                          search_for:       find_string,
                                                          regex_search:     false,
                                                          case_insensitive: true)

      allow(search).to receive(:search_timeout).and_return(0.01.seconds)
      allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
        sleep(0.01)
        orig_function.call(*args)
      end

      search.search
      num_searches = 1
      class_results.concat search.class_results
      run_results.concat search.run_results

      expect(search.more_records?).to be_truthy

      while search.more_records?
        search = Resque::Plugins::JobHistory::JobSearch.new(search.search_settings(true))

        allow(search).to receive(:search_timeout).and_return(0.01.seconds)
        allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
          sleep(0.01)
          orig_function.call(*args)
        end

        search.search
        num_searches += 1
        class_results.concat search.class_results
        run_results.concat search.run_results
      end

      # Once for every job class
      # Once for every job in each class
      # Once to verify that there are no more results.
      expect(num_searches).to eq jobs.flatten.length + test_jobs.length + 1

      expect(class_results.length).to eq 1
      expect(run_results.length).to eq 4

      expect(class_results.first.class_name).to eq "CustomPageSizeJob"

      # sorted by class name, then running, then finished.
      expect(run_results[0].job_id).to eq jobs[1][2].job_id
      expect(run_results[1].job_id).to eq jobs[1][3].job_id
      expect(run_results[2].job_id).to eq jobs[0][2].job_id
      expect(run_results[3].job_id).to eq jobs[0][3].job_id
    end

    it "can stop then resume linear searches" do
      jobs.flatten.each do |job|
        job.running_jobs.remove_job(job.job_id)
        job.finished_jobs.remove_job(job.job_id)
      end

      class_results = []
      run_results   = []

      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_linear_history",
                                                          search_for:       find_string,
                                                          regex_search:     true,
                                                          case_insensitive: true)

      allow(search).to receive(:search_timeout).and_return(0.01.seconds)
      allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
        sleep(0.01)
        orig_function.call(*args)
      end

      search.search
      num_searches = 1
      class_results.concat search.class_results
      run_results.concat search.run_results

      expect(search.more_records?).to be_truthy

      while search.more_records?
        search = Resque::Plugins::JobHistory::JobSearch.new(search.search_settings(true))

        allow(search).to receive(:search_timeout).and_return(0.01.seconds)
        allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
          sleep(0.01)
          orig_function.call(*args)
        end

        search.search
        num_searches += 1
        class_results.concat search.class_results
        run_results.concat search.run_results
      end

      # Once for every job class
      # Once for every job in each class
      # Once to verify that there are no more results.
      expect(num_searches).to eq jobs.flatten.length + 1

      expect(class_results.length).to eq 0
      expect(run_results.length).to eq 4

      # sorted by create order reversed
      expect(run_results[0].job_id).to eq jobs[1][3].job_id
      expect(run_results[1].job_id).to eq jobs[1][2].job_id
      expect(run_results[2].job_id).to eq jobs[0][3].job_id
      expect(run_results[3].job_id).to eq jobs[0][2].job_id
    end

    it "refinds a running job that finishes during the search" do
      class_results = []
      run_results   = []

      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_job",
                                                          job_class_name:   "CustomPageSizeJob",
                                                          search_for:       find_string,
                                                          regex_search:     false,
                                                          case_insensitive: true)

      allow(search).to receive(:search_timeout).and_return(0.01.seconds)
      allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
        sleep(0.01)
        orig_function.call(*args)
      end

      search.search
      num_searches = 1
      class_results.concat search.class_results
      run_results.concat search.run_results

      jobs[0][2].finish

      expect(search.more_records?).to be_truthy

      while search.more_records?
        search = Resque::Plugins::JobHistory::JobSearch.new(search.search_settings(true))

        allow(search).to receive(:search_timeout).and_return(0.01.seconds)
        allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
          sleep(0.01)
          orig_function.call(*args)
        end

        search.search
        num_searches += 1

        class_results.concat search.class_results
        run_results.concat search.run_results
      end

      # Once for every job in the class
      # Once to verify that there are no more results.
      expect(num_searches).to eq jobs[0].length + 1

      expect(class_results.length).to eq 0
      expect(run_results.length).to eq 3

      # sorted by create order reversed
      # First job found in the initial search, then again in the finished search.
      expect(run_results[0].job_id).to eq jobs[0][2].job_id
      expect(run_results[1].job_id).to eq jobs[0][2].job_id
      expect(run_results[2].job_id).to eq jobs[0][3].job_id
    end

    it "will skip running searches if the job is no longer there" do
      class_results = []
      run_results   = []

      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_job",
                                                          job_class_name:   "CustomPageSizeJob",
                                                          search_for:       find_regex,
                                                          regex_search:     true,
                                                          case_insensitive: true)

      allow(search).to receive(:search_timeout).and_return(0.01.seconds)
      allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
        sleep(0.01)
        orig_function.call(*args)
      end

      search.search
      num_searches = 1
      class_results.concat search.class_results
      run_results.concat search.run_results

      jobs[0][2].finish

      expect(search.more_records?).to be_truthy

      while search.more_records?
        search = Resque::Plugins::JobHistory::JobSearch.new(search.search_settings(true))

        allow(search).to receive(:search_timeout).and_return(0.01.seconds)
        allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
          sleep(0.01)
          orig_function.call(*args)
        end

        search.search
        num_searches += 1

        class_results.concat search.class_results
        run_results.concat search.run_results
      end

      # Once for every job in the class
      # Once to verify that there are no more results.
      # Minus one for the skipped search
      expect(num_searches).to eq jobs[0].length + 1

      expect(class_results.length).to eq 0
      expect(run_results.length).to eq 1

      # sorted by create order reversed
      # First job found in the initial search, then again in the finished search.
      expect(run_results[0].job_id).to eq jobs[0][0].job_id
    end

    it "will skip finished searches if the job is no longer there" do
      class_results = []
      run_results   = []

      search = Resque::Plugins::JobHistory::JobSearch.new(search_type:      "search_job",
                                                          job_class_name:   "CustomPageSizeJob",
                                                          search_for:       find_regex,
                                                          regex_search:     true,
                                                          case_insensitive: true)

      allow(search).to receive(:search_timeout).and_return(0.01.seconds)
      allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
        sleep(0.01)
        orig_function.call(*args)
      end

      search.search
      num_searches = 1
      class_results.concat search.class_results
      run_results.concat search.run_results

      expect(search.more_records?).to be_truthy

      while search.more_records?
        search = Resque::Plugins::JobHistory::JobSearch.new(search.search_settings(true))

        allow(search).to receive(:search_timeout).and_return(0.01.seconds)
        allow(search).to receive(:validate_string).and_wrap_original do |orig_function, *args|
          sleep(0.01)
          orig_function.call(*args)
        end

        search.search
        num_searches += 1
        if num_searches == 3
          jobs[0][0].running_jobs.remove_job(jobs[0][4].job_id)
          jobs[0][0].finished_jobs.remove_job(jobs[0][4].job_id)
        end

        class_results.concat search.class_results
        run_results.concat search.run_results
      end

      # Once for every job in the class
      # Once to verify that there are no more results.
      # Minus one for the skipped search
      expect(num_searches).to eq 4

      expect(class_results.length).to eq 0
      expect(run_results.length).to eq 1

      # sorted by create order reversed
      # First job to be found skipped because last found run finished.
      expect(run_results[0].job_id).to eq jobs[0][1].job_id
    end
  end
end
