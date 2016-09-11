# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::JobHistory::HistoryList do
  let(:history_jobs) { Resque::Plugins::JobHistory::HistoryList.new "CustomHistoryLengthJob", "test" }
  let(:test_history_jobs) { Resque::Plugins::JobHistory::HistoryList.new "CustomHistoryLengthJob", "test" }
  let(:job_list) { Resque::Plugins::JobHistory::JobList.new }
  let(:job_id) { SecureRandom.uuid }

  describe "#add_job" do
    it "adds the job class to the list of job classes" do
      expect { history_jobs.add_job(job_id) }.to change { job_list.job_classes.length }.by 1
      expect(job_list.job_classes).to be_include("CustomHistoryLengthJob")
    end

    it "adds the job to the list" do
      expect { history_jobs.add_job(job_id) }.to change { test_history_jobs.num_jobs }.by 1
      expect(test_history_jobs.job_ids).to be_include(job_id)
    end

    it "increments the total count" do
      Array.new(50) { history_jobs.add_job(SecureRandom.uuid) }

      expect do
        expect { history_jobs.add_job(job_id) }.not_to change { test_history_jobs.num_jobs }
      end.to change { test_history_jobs.total }.by(1)
    end

    it "deletes the jobs over the max count" do
      job_ids = Array.new(55) { SecureRandom.uuid }
      job_ids.each { |added_id| history_jobs.add_job(added_id) }

      history_jobs.add_job(job_id)
      expect(test_history_jobs.job_ids).to be_include(job_id)
      Array.new(5) do |index|
        expect(test_history_jobs.job_ids).not_to be_include(job_ids[index])
      end
    end

    it "returns the number of jobs after this is added" do
      job_ids = Array.new(15) { SecureRandom.uuid }
      job_ids.each { |added_id| history_jobs.add_job(added_id) }

      expect(history_jobs.add_job(job_id)).to eq 16
    end

    it "returns the number of jobs after this is added if it purges jobs" do
      job_ids = Array.new(55) { SecureRandom.uuid }
      job_ids.each { |added_id| history_jobs.add_job(added_id) }

      expect(history_jobs.add_job(job_id)).to eq 50
    end
  end

  it "removes a job from the list no matter where it islocated" do
    job_ids = Array.new(50) { SecureRandom.uuid }
    job_ids.each { |added_id| history_jobs.add_job(added_id) }
    job_id = job_ids.sample

    expect { history_jobs.remove_job(job_id) }.to change { test_history_jobs.num_jobs }.by(-1)

    expect(test_history_jobs.job_ids).not_to be_include(job_id)
  end

  describe "paged_jobs" do
    it "returns a list of jobs based on paged information" do
      job_ids = Array.new(50) { SecureRandom.uuid }
      job_ids.reverse.each { |added_id| history_jobs.add_job(added_id) }
      page_num = rand(1..24)

      jobs = test_history_jobs.paged_jobs(page_num, "2")
      expect(jobs.map(&:job_id)).to eq job_ids[(page_num - 1) * 2..((page_num - 1) * 2) + 1]
    end

    it "returns a page based on the classes custom page size by default" do
      test_jobs = Resque::Plugins::JobHistory::HistoryList.new "CustomPageSizeJob", "test"
      job_ids   = Array.new(50) { SecureRandom.uuid }

      job_ids.each { |added_id| test_jobs.add_job(added_id) }

      jobs = test_jobs.paged_jobs(rand(1..4), nil)
      expect(jobs.length).to eq 10
    end

    it "returns a page based on the default page size for invalid classes" do
      test_jobs = Resque::Plugins::JobHistory::HistoryList.new "InvalidCustomPageSizeJob", "test"
      job_ids   = Array.new(50) { SecureRandom.uuid }

      job_ids.each { |added_id| test_jobs.add_job(added_id) }

      jobs = test_jobs.paged_jobs(rand(1..2), nil)
      expect(jobs.length).to eq 25
    end

    it "returns a page based on the default page size if the page size is invalid" do
      test_jobs = Resque::Plugins::JobHistory::HistoryList.new "InvalidCustomPageSizeJob", "test"
      job_ids   = Array.new(50) { SecureRandom.uuid }

      job_ids.each { |added_id| test_jobs.add_job(added_id) }

      jobs = test_jobs.paged_jobs(rand(1..2), "0")
      expect(jobs.length).to eq 25
    end
  end

  it "returns a count of the number of jobs in the list" do
    job_ids = Array.new(rand(1..20)) { SecureRandom.uuid }
    job_ids.each { |added_id| history_jobs.add_job(added_id) }

    expect(test_history_jobs.num_jobs).to eq job_ids.length
  end

  it "returns a count of the number of jobs that had been in the list" do
    job_ids = Array.new(rand(51..70)) { SecureRandom.uuid }
    job_ids.each { |added_id| history_jobs.add_job(added_id) }

    expect(test_history_jobs.num_jobs).to eq 50
    expect(test_history_jobs.total).to eq job_ids.length
  end

  it "returns the most recently added job to the lsit" do
    job_ids = Array.new(rand(2..15)) { SecureRandom.uuid }
    job_ids.each { |added_id| history_jobs.add_job(added_id) }

    expect(test_history_jobs.latest_job.job_id).to eq job_ids[-1]
  end
end
