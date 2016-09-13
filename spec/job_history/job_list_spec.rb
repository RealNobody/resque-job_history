# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::JobHistory::JobList do
  let(:all_valid_jobs) do
    [BasicJob,
     CustomHistoryLengthJob,
     CustomPageSizeJob,
     CustomPurgeAgeJob,
     ExcludeLiniearHistoryJob]
  end
  let(:all_invalid_jobs) do
    %w(InvalidBasicJob
       InvalidCustomHistoryLengthJob
       InvalidCustomPageSizeJob
       InvalidCustomPurgeAgeJob,
       InvalidExcludeLiniearHistoryJob)
  end
  let(:tester) { JobSummarySortTester.new self }
  let(:all_jobs) { (all_valid_jobs.map(&:name) | all_invalid_jobs).sample(1_000) }
  let(:job_list) { Resque::Plugins::JobHistory::JobList.new }
  let(:job_summaries) { JobSummaryBuilder.new.build_job_summaries(all_jobs) }

  before(:each) do
    job_summaries
  end

  describe "#order_param" do
    it "returns asc for any column other than the current one" do
      expect(job_list.order_param("sort_option", "current_sort", %w(asc desc).sample)).to eq "asc"
    end

    it "returns desc for the current column if it is asc" do
      expect(job_list.order_param("sort_option", "sort_option", "asc")).to eq "desc"
    end

    it "returns asc for the current column if it is desc" do
      expect(job_list.order_param("sort_option", "sort_option", "desc")).to eq "asc"
    end
  end

  describe "#job_summaries" do
    context "ascending" do
      it "sorts the list of jobs by class_name" do
        tester.test_ascending(job_list, :class_name)
      end

      it "sorts the list of jobs by running_jobs" do
        tester.test_ascending(job_list, :running_jobs)
      end

      it "sorts the list of jobs by finished_jobs" do
        tester.test_ascending(job_list, :finished_jobs)
      end

      it "sorts the list of jobs by total_finished_jobs" do
        tester.test_ascending(job_list, :total_finished_jobs)
      end

      it "sorts the list of jobs by total_run_jobs" do
        tester.test_ascending(job_list, :total_run_jobs)
      end

      it "sorts the list of jobs by max_running_jobs" do
        tester.test_ascending(job_list, :max_running_jobs)
      end

      it "sorts the list of jobs by start_time" do
        tester.test_last_ascending(job_list, :start_time, :start_time)
      end

      it "sorts the list of jobs by duration" do
        tester.test_last_ascending(job_list, :duration, :duration)
      end

      it "sorts the list of jobs by success" do
        prev_value = ""
        Array.new(4) do |index|
          jobs = job_list.job_summaries(:success, "asc", index + 1, 2)

          jobs.each do |job|
            unless prev_value.blank?
              expect(job[:last_run].succeeded? ? 1 : 0).to be >= prev_value
            end

            prev_value = job[:last_run].succeeded? ? 1 : 0
          end
        end
      end
    end

    context "descending" do
      it "sorts the list of jobs by class_name" do
        tester.test_descending(job_list, :class_name)
      end

      it "sorts the list of jobs by running_jobs" do
        tester.test_descending(job_list, :running_jobs)
      end

      it "sorts the list of jobs by finished_jobs" do
        tester.test_descending(job_list, :finished_jobs)
      end

      it "sorts the list of jobs by total_finished_jobs" do
        tester.test_descending(job_list, :total_finished_jobs)
      end

      it "sorts the list of jobs by total_run_jobs" do
        tester.test_descending(job_list, :total_run_jobs)
      end

      it "sorts the list of jobs by max_running_jobs" do
        tester.test_descending(job_list, :max_running_jobs)
      end

      it "sorts the list of jobs by start_time" do
        tester.test_last_descending(job_list, :start_time, :start_time)
      end

      it "sorts the list of jobs by duration" do
        tester.test_last_descending(job_list, :duration, :duration)
      end

      it "sorts the list of jobs by success" do
        prev_value = ""
        Array.new(4) do |index|
          jobs = job_list.job_summaries(:success, "desc", index + 1, 2)

          jobs.each do |job|
            unless prev_value.blank?
              expect(job[:last_run].succeeded? ? 1 : 0).to be <= prev_value
            end

            prev_value = job[:last_run].succeeded? ? 1 : 0
          end
        end
      end
    end
  end

  describe "#job_classes" do
    it "returns a list of all of the jobs that have been run" do
      job_classes = job_list.job_classes

      expect(job_classes.sort).to eq all_jobs.sort
    end
  end

  describe "#job_class_summary" do
    it "returns the summary for the passed in class" do
      all_jobs.each do |class_name|
        tester.test_summaries(class_name, job_summaries)
      end
    end
  end
end
