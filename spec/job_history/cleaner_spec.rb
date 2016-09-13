# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::JobHistory::Cleaner do
  let(:cleaner) { Resque::Plugins::JobHistory::Cleaner }
  let(:all_valid_jobs) do
    [BasicJob,
     CustomHistoryLengthJob,
     CustomPageSizeJob,
     CustomPurgeAgeJob]
  end
  let(:all_invalid_jobs) do
    %w(InvalidBasicJob
       InvalidCustomHistoryLengthJob
       InvalidCustomPageSizeJob
       InvalidCustomPurgeAgeJob)
  end
  let(:tester) { JobSummarySortTester.new self }
  let(:all_jobs) { (all_valid_jobs.map(&:name) | all_invalid_jobs).sample(1_000) }
  let(:job_summaries) { JobSummaryBuilder.new.build_job_summaries(all_jobs) }
  let(:job_list) { Resque::Plugins::JobHistory::JobList.new }
  let(:job_id) { SecureRandom.uuid.to_s }
  let(:job) { Resque::Plugins::JobHistory::Job.new "CustomHistoryLengthJob", job_id }

  before(:each) do
    job_summaries
  end

  it "cleans old running jobs for each job class" do
    received_list = []
    allow_any_instance_of(Resque::Plugins::JobHistory::HistoryDetails).
        to receive(:clean_old_running_jobs) do |instance|
      received_list << instance.class_name
    end

    cleaner.clean_all_old_running_jobs

    expect(received_list.sort).to eq job_list.job_classes.sort
  end

  it "fixes the job keys for each job class" do
    job_list.job_classes.each do |class_name|
      expect(cleaner).to receive(:fixup_job_keys).with class_name
    end

    cleaner.fixup_all_keys
  end

  describe "#fixup_job_keys" do
    it "purges stranded jobs" do
      other_job = Resque::Plugins::JobHistory::Job.new "BasicJob", SecureRandom.uuid
      other_job.start
      job.start
      job.running_jobs.remove_job(job_id)
      job.linear_jobs.remove_job(job_id)

      expect(job.redis.keys("*#{other_job.job_id}*")).not_to be_blank
      expect(job.redis.keys("*#{job_id}*")).not_to be_blank
      expect { cleaner.fixup_job_keys(job.class_name) }.not_to change { job.running_jobs.num_jobs }
      expect(job.redis.keys("*#{job_id}*")).to be_blank
      expect(job.redis.keys("*#{other_job.job_id}*")).not_to be_blank
    end

    it "deletes other non-job keys" do
      job.start
      job.finish
      job.redis.set("job_history.#{job.class_name}.#{job_id}.something stupid", "silly")
      job.finished_jobs.remove_job(job_id)
      job.linear_jobs.remove_job(job_id)

      expect(job.redis.keys("*#{job_id}*")).not_to be_blank
      expect { cleaner.fixup_job_keys(job.class_name) }.not_to change { job.finished_jobs.num_jobs }
      expect(job.redis.keys("*#{job_id}*")).to be_blank
    end

    it "does not deletes job keys in the linear list" do
      job.start
      job.finish
      job.redis.set("job_history.#{job.class_name}.#{job_id}.something stupid", "silly")
      job.finished_jobs.remove_job(job_id)

      expect(job.redis.keys("*#{job_id}*")).not_to be_blank
      expect { cleaner.fixup_job_keys(job.class_name) }.not_to change { job.finished_jobs.num_jobs }
      expect(job.redis.keys("*#{job_id}*")).not_to be_blank
      expect(job.redis.keys("*#{job_id}*something stupid")).to be_blank
    end

    it "deletes other non-job keys of purged jobs" do
      job.start
      job.finish
      job.redis.set("job_history.#{job.class_name}.#{job_id}.something stupid", "silly")
      job.purge

      expect(job.redis.keys("*#{job_id}*")).not_to be_blank
      expect { cleaner.fixup_job_keys(job.class_name) }.not_to change { job.finished_jobs.num_jobs }
      expect(job.redis.keys("*#{job_id}*")).to be_blank
    end

    it "does not delete any valid jobs" do
      Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", SecureRandom.uuid).start

      job.start
      job.cancel
      job.redis.set("job_history.#{job.class_name}.#{job_id}.something stupid", "silly")
      job.finished_jobs.remove_job(job_id)
      job.linear_jobs.remove_job(job_id)

      expect(job.redis.keys("*#{job_id}*")).not_to be_blank
      expect { cleaner.fixup_job_keys(job.class_name) }.
          not_to change { [job.running_jobs.num_jobs, job.finished_jobs.num_jobs, job.linear_jobs.num_jobs] }
      expect(job.redis.keys("*#{job_id}*")).to be_blank
      expect(job.finished_jobs.num_jobs).to be >= 1
      expect(job.running_jobs.num_jobs).to be >= 1
      expect(job.linear_jobs.num_jobs).to be >= 1
      expect(job.finished_jobs.job_ids).not_to be_include(job_id)
      expect(job.running_jobs.job_ids).not_to be_include(job_id)
      expect(job.linear_jobs.job_ids).not_to be_include(job_id)
    end
  end

  describe "#purge_all_jobs" do
    after(:each) do
      Resque.redis.del("erik test key")
    end

    it "purges every class" do
      job_list.job_classes.each do |class_name|
        expect(cleaner).to receive(:purge_class).with class_name
      end

      cleaner.purge_all_jobs
    end

    it "deletes the job list key" do
      cleaner.purge_all_jobs

      expect(job_list.redis.get(Resque::Plugins::JobHistory::HistoryDetails.job_history_key)).to be_nil
    end

    it "deletes any other keys in the namespace" do
      job_list.redis.set("fred is stupid", "something")

      cleaner.purge_all_jobs

      expect(job_list.redis.keys("*")).to be_blank
    end

    it "does not delete non-namespace keys" do
      Resque.redis.set("erik test key", "something")

      cleaner.purge_all_jobs

      expect(Resque.redis.get("erik test key")).to eq "something"
    end
  end

  describe "#purge_invalid_jobs" do
    it "purges all classes that cannot be instantiated" do
      cleaner.purge_invalid_jobs

      all_invalid_jobs.each do |class_name|
        stats = job_list.job_class_summary(class_name)
        expect(stats[:class_name_valid]).to be_falsey
        expect(stats[:running_jobs]).to eq 0
        expect(stats[:finished_jobs]).to eq 0
        expect(stats[:total_run_jobs]).to eq 0
        expect(stats[:total_finished_jobs]).to eq 0
        expect(stats[:max_concurrent_jobs]).to eq 0
        expect(stats[:total_failed_jobs]).to eq 0
        expect(stats[:last_run]).to be_nil
      end
    end

    it "does not purt valid classes" do
      all_valid_jobs.each do |valid_class|
        tester.test_summaries(valid_class.name, job_summaries)
      end
    end
  end

  describe "#purge_class" do
    let(:purge_class) { all_jobs.sample }
    let(:not_purge_classes) { all_jobs - [purge_class] }

    it "purges all keys for a class" do
      purge_job = Resque::Plugins::JobHistory::Job.new purge_class, job_id

      purge_job.redis.set("job_history.#{purge_job.class_name}something stupid", "silly")

      cleaner.purge_class(purge_class)

      expect(purge_job.redis.get("job_history.#{purge_job.class_name}something stupid")).to be_nil
    end

    it "does not purge keys for other classes" do
      Resque::Plugins::JobHistory::Job.new purge_class, job_id

      cleaner.purge_class(purge_class)

      not_purge_classes.each do |valid_class|
        tester.test_summaries(valid_class, job_summaries)
      end
    end
  end

  describe "#similar_name?" do
    let(:similar_job_class) { all_jobs.sample }

    it "returns true if there is another class that starts with the same name" do
      similar_job = Resque::Plugins::JobHistory::Job.new "#{similar_job_class}SubClass", job_id

      similar_job.start

      expect(cleaner.similar_name?(similar_job_class)).to be_truthy
    end

    it "does not purge a class if there is a similar name" do
      purge_job   = Resque::Plugins::JobHistory::Job.new similar_job_class, job_id
      similar_job = Resque::Plugins::JobHistory::Job.new "#{similar_job_class}SubClass", job_id

      similar_job.start

      purge_job.redis.set("job_history.#{purge_job.class_name}something stupid", "silly")

      cleaner.purge_class(similar_job_class)

      expect(purge_job.redis.get("job_history.#{purge_job.class_name}something stupid")).not_to be_nil
    end
  end

  describe "#fixup_linear_keys" do
    it "removes jobs from the class list that are stranded" do
      job.start
      job.redis.lrem("job_history..linear_jobs", 0, job.job_id)

      expect(job.redis.hget("job_history..linear_job_classes", job.job_id)).to eq job.class_name

      cleaner.fixup_linear_keys

      expect(job.redis.hget("job_history..linear_job_classes", job.job_id)).not_to be
    end

    it "doesn't affect valid jobs" do
      other_job = Resque::Plugins::JobHistory::Job.new "BasicJob", SecureRandom.uuid
      other_job.start
      job.start
      job.redis.lrem("job_history..linear_jobs", 0, job.job_id)

      expect(job.redis.hget("job_history..linear_job_classes", job.job_id)).to eq job.class_name
      expect(job.redis.hget("job_history..linear_job_classes", other_job.job_id)).to eq other_job.class_name

      cleaner.fixup_linear_keys

      expect(job.redis.hget("job_history..linear_job_classes", job.job_id)).not_to be
      expect(job.redis.hget("job_history..linear_job_classes", other_job.job_id)).to eq other_job.class_name
    end
  end
end
