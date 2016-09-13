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

  describe ".around_perform_job_history" do
    let(:job_class) { BasicJob }
    let(:job) { Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid) }
    let(:test_args) do
      rand_args = []
      rand_args << Faker::Lorem.sentence
      rand_args << Faker::Lorem.paragraph
      rand_args << SecureRandom.uuid.to_s
      rand_args << rand(0..1_000_000_000_000_000_000_000_000).to_s
      rand_args << rand(0..1_000_000_000_000).seconds.ago.to_s
      rand_args << rand(0..1_000_000_000_000).seconds.from_now.to_s
      rand_args << Array.new(rand(1..5)) { Faker::Lorem.word }
      rand_args << Array.new(rand(1..5)).each_with_object({}) do |_nil_value, sub_hash|
        sub_hash[Faker::Lorem.word] = Faker::Lorem.word
      end

      rand_args = rand_args.sample(rand(3..rand_args.length))

      if [true, false].sample
        options_hash                    = {}
        options_hash[Faker::Lorem.word] = Faker::Lorem.sentence
        options_hash[Faker::Lorem.word] = Faker::Lorem.paragraph
        options_hash[Faker::Lorem.word] = SecureRandom.uuid.to_s
        options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000_000_000_000_000).to_s
        options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.ago.to_s
        options_hash[Faker::Lorem.word] = rand(0..1_000_000_000_000).seconds.from_now.to_s
        options_hash[Faker::Lorem.word] = Array.new(rand(1..5)) { Faker::Lorem.word }
        options_hash[Faker::Lorem.word] = Array.new(rand(1..5)).
            each_with_object({}) do |_nil_value, sub_hash|
          sub_hash[Faker::Lorem.word] = Faker::Lorem.word
        end

        rand_args << options_hash.slice(*options_hash.keys.sample(rand(5..options_hash.keys.length)))
      end

      rand_args
    end

    before(:each) do
      job
      expect(Resque::Plugins::JobHistory::Job).to receive(:new).exactly(1).times.and_return job
    end

    it "yields to the passed in block" do
      called = false

      job_class.around_perform_job_history(*test_args) do
        called = true
      end

      expect(called).to be_truthy
    end

    it "starts a job" do
      expect(job).to receive(:start).with(*test_args)

      job_class.around_perform_job_history(*test_args) do
      end
    end

    it "finishes a job" do
      expect(job).to receive(:finish)

      job_class.around_perform_job_history(*test_args) do
      end
    end

    it "re-raises any exception that is raised" do
      expect do
        job_class.around_perform_job_history(*test_args) do
          raise StandardError, "This is an error"
        end
      end.to raise_error StandardError, "This is an error"
    end

    it "records failures" do
      expect(job).to receive(:failed).with(StandardError)

      expect do
        job_class.around_perform_job_history(*test_args) do
          raise StandardError, "This is an error"
        end
      end.to raise_error StandardError, "This is an error"
    end
  end
end
