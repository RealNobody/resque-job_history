# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::JobHistory do
  let(:all_jobs) do
    [BasicJob,
     CustomHistoryLengthJob,
     CustomPageSizeJob,
     CustomPurgeAgeJob,
     ExcludeLiniearHistoryJob]
  end
  let(:history_class) { all_jobs.sample }
  let(:other_histories) { all_jobs - [history_class] }
  let(:failure_exception) { StandardError.new("Something happened.") }

  before(:each) do
    history_class.instance_variable_set(:@running_job, nil)
  end

  it "should be compliance with Resqu::Plugin document" do
    expect { Resque::Plugin.lint(Resque::Plugins::JobHistory) }.to_not raise_error
  end

  describe ".job_history_len" do
    it "defaults the number of histories" do
      (all_jobs - [CustomHistoryLengthJob]).each do |job|
        expect(job.job_history_len).to eq Resque::Plugins::JobHistory::MAX_JOB_HISTORY
      end
    end

    it "allows a class to override the number of histories" do
      expect(CustomHistoryLengthJob.job_history_len).to eq 50
    end
  end

  describe ".purge_age" do
    it "defaults the age of a job before it is purged" do
      (all_jobs - [CustomPurgeAgeJob]).each do |job|
        expect(job.purge_age).to eq Resque::Plugins::JobHistory::PURGE_AGE
      end
    end

    it "allows a class to override the age of a job before it is purged" do
      expect(CustomPurgeAgeJob.purge_age).to eq 1.hour
    end
  end

  describe ".page_size" do
    it "defaults the number of displayed runs" do
      (all_jobs - [CustomPageSizeJob]).each do |job|
        expect(job.page_size).to eq Resque::Plugins::JobHistory::PAGE_SIZE
      end
    end

    it "allows a class to override the number of displayed runs" do
      expect(CustomPageSizeJob.page_size).to eq 10
    end
  end

  describe "#job_history" do
    it "returns a class that allows you to query the details about the history for the job" do
      all_jobs.each do |job|
        expect(job.job_history).to be_a(Resque::Plugins::JobHistory::HistoryDetails)
      end
    end

    it "keeps separate histories for separate jobs" do
      Resque.enqueue history_class

      other_histories.each do |job|
        expect(job.job_history.finished_jobs.num_jobs).to eq 0
      end

      expect(history_class.job_history.finished_jobs.num_jobs).to eq 1
    end
  end

  describe ".before_perform_job_history" do
    it "cancels the previous history if something happens and it is still working" do
      history_class.before_perform_job_history

      expect(history_class.running_job).to receive(:cancel).and_call_original
      history_class.before_perform_job_history
    end

    it "creates a new job" do
      expect(Resque::Plugins::JobHistory::Job).
          to receive(:new).and_wrap_original do |original_function, job_name, job_id|
        expect(job_name).to eq history_class.name
        expect(job_id).not_to be_empty
        expect(job_id).to be_instance_of(String)

        original_function.call(job_name, job_id)
      end

      history_class.before_perform_job_history
    end

    it "starts the new job" do
      expect(Resque::Plugins::JobHistory::Job).to receive(:new).
          and_wrap_original do |original_function, job_name, job_id|
        new_object = original_function.call(job_name, job_id)

        expect(new_object).to receive(:start).and_call_original

        new_object
      end

      history_class.before_perform_job_history
    end
  end

  describe ".after_perform_job_history" do
    it "finishes the running job" do
      history_class.before_perform_job_history

      expect(history_class.running_job).to receive(:finish).and_call_original

      history_class.after_perform_job_history
    end

    it "does nothing if there is no job" do
      expect(history_class.running_job).not_to be
      expect { history_class.after_perform_job_history }.not_to raise_error
    end

    it "clears the running job" do
      history_class.before_perform_job_history
      history_class.after_perform_job_history

      expect(history_class.running_job).not_to be
    end
  end

  describe ".on_failure_job_history" do
    it "fails the running job" do
      history_class.before_perform_job_history

      expect(history_class.running_job).to receive(:failed).with(failure_exception).and_call_original

      history_class.on_failure_job_history failure_exception
    end

    it "does nothing if there is no job" do
      expect(history_class.running_job).not_to be
      expect { history_class.after_perform_job_history }.not_to raise_error
    end

    it "clears the running job" do
      history_class.before_perform_job_history
      history_class.on_failure_job_history failure_exception

      expect(history_class.running_job).not_to be
    end
  end
end
