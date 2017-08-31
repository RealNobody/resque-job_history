# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::JobHistory::Job do
  let(:job_id) { SecureRandom.uuid.to_s }
  let(:job) { Resque::Plugins::JobHistory::Job.new "CustomHistoryLengthJob", job_id }
  let(:test_job) { Resque::Plugins::JobHistory::Job.new "CustomHistoryLengthJob", job_id }
  let(:error_message) { Faker::Lorem.sentence }
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

  around(:each) do |example_proxy|
    Timecop.freeze do
      example_proxy.call
    end
  end

  it "returns the key for the job" do
    expect(job.job_key).to eq "job_history.CustomHistoryLengthJob.#{job_id}"
  end

  context "an existing job" do
    before(:each) do
      Timecop.freeze(1.hours.ago) do
        job.start
      end
    end

    it "returns the jobs start time" do
      test_time = Time.parse(1.hour.ago.utc.to_s)

      Timecop.freeze(2.hours.from_now) do
        expect(test_job.start_time).to eq test_time
      end
    end

    it "returns the starting arguments to the job" do
      job_with_args = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
      job_with_args.start(*test_args)

      test_job_with_args = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
      expect(test_job_with_args.args).to eq test_args
    end

    context "running" do
      it "returns if the job finished" do
        expect(test_job.finished?).to be_falsey
      end

      it "returns the duration of a running job" do
        expect(test_job.duration).to eq(Time.now - job.start_time)
      end

      it "returns the end_time of the job" do
        expect(test_job.end_time).not_to be
      end

      it "returns if the job succeeded" do
        expect(test_job.succeeded?).to be_truthy
      end
    end

    context "finished" do
      before(:each) do
        Timecop.freeze(30.minutes.ago) do
          job.finish
        end
      end

      it "returns if the job didn't finish" do
        expect(test_job.finished?).to be_truthy
      end

      it "returns if a failed job didn't finish" do
        failed_job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
        Timecop.freeze(1.hours.ago) do
          failed_job.start
          failed_job.failed(StandardError.new(error_message))
        end

        test_failed_job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
        expect(test_failed_job.finished?).to be_truthy
      end

      it "returns if the job succeeded" do
        expect(test_job.succeeded?).to be_truthy
      end

      it "returns if the job didn't succeed" do
        failed_job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
        Timecop.freeze(1.hours.ago) do
          failed_job.start
          failed_job.failed(StandardError.new(error_message))
        end

        test_failed_job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
        expect(test_failed_job.succeeded?).to be_falsey
      end

      it "returns the duration of the job" do
        expect(test_job.duration).to eq 30.minutes
      end

      it "returns the end_time of the job" do
        expect(test_job.end_time).to eq Time.parse(30.minutes.ago.to_s)
      end

      it "returns the error of a failed job" do
        failed_job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
        Timecop.freeze(1.hours.ago) do
          failed_job.start
          failed_job.failed(StandardError.new(error_message))
        end

        test_failed_job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", job_id)
        expect(test_failed_job.error).to eq error_message
      end
    end
  end

  context "a new job" do
    describe "start" do
      it "adds the job to the job list" do
        job.start

        expect(Resque::Plugins::JobHistory::JobList.new.job_classes).to eq ["CustomHistoryLengthJob"]
      end

      it "adds the job to the running list" do
        expect { job.start }.to change { test_job.running_jobs.num_jobs }.by(1)
      end

      it "adds the job to the linear list" do
        expect { job.start }.to change { test_job.linear_jobs.num_jobs }.by(1)
      end

      it "does not add the job to the linear list if it is excluded" do
        exclude_job      = Resque::Plugins::JobHistory::Job.new "ExcludeLiniearHistoryJob", job_id
        test_exclude_job = Resque::Plugins::JobHistory::Job.new "ExcludeLiniearHistoryJob", job_id

        expect { exclude_job.start }.not_to(change { test_exclude_job.linear_jobs.num_jobs })
      end

      it "saves the args" do
        job.start(*test_args)

        expect(test_job.args).to eq test_args
      end

      it "records the start time" do
        job.start
        expect(test_job.start_time).to eq Time.parse(Time.now.to_s)
      end

      it "does not change the max running jobs if there are fewer running jobs than the current max" do
        jobs = Array.new(rand(3..5)).map do
          job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", SecureRandom.uuid)
          job.start
          job
        end
        jobs.each(&:finish)

        expect { job.start }.
            not_to(change do
              Resque::Plugins::JobHistory::HistoryDetails.new("CustomHistoryLengthJob").max_concurrent_jobs
            end)
      end

      it "changes the max running jobs if there are more running jobs than the current max" do
        Array.new(rand(3..5)).map do
          job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", SecureRandom.uuid)
          job.start
          job
        end

        expect { job.start }.to(change do
          Resque::Plugins::JobHistory::HistoryDetails.new("CustomHistoryLengthJob").max_concurrent_jobs
        end.by(1))
      end

      it "cleans out old jobs if there are too many running jobs" do
        jobs = Array.new(50).map do
          Timecop.travel(3.days.ago) do
            job = Resque::Plugins::JobHistory::Job.new("CustomHistoryLengthJob", SecureRandom.uuid)
            job.start
            job
          end
        end

        expect(job).to receive(:clean_old_running_jobs).and_call_original

        job.start

        expect(test_job.running_jobs.num_jobs).to eq 1
        expect(jobs[-1].finished?).to be_truthy
        expect(jobs[-1].succeeded?).to be_falsey
      end
    end

    describe "finish" do
      it "records the end time" do
        job.start
        job.finish

        expect(test_job.end_time).to eq Time.parse(Time.now.to_s)
      end

      it "marks the job finished" do
        job.start
        job.finish

        expect(test_job.finished?)
      end

      it "marks the job successful" do
        job.start
        job.finish

        expect(test_job.succeeded?).to be_truthy
      end

      it "adds the job to the finished list" do
        job.start

        expect { job.finish }.to change { test_job.finished_jobs.num_jobs }.by(1)
      end

      it "removes the job from the running list" do
        job.start

        expect { job.finish }.to change { test_job.running_jobs.num_jobs }.by(-1)
      end

      it "does not change the linear list" do
        job.start

        expect { job.finish }.not_to(change { test_job.linear_jobs.num_jobs })
      end
    end

    describe "failed" do
      it "includes the backtrace for DirtyExit" do
        test_error = nil

        begin
          raise StandardError, error_message
        rescue StandardError => dirty_error
          test_error = Resque::DirtyExit.new("Testing DirtyExit", dirty_error)
        end

        job.start
        job.failed(test_error)

        expect(test_job.error).to be_include("Testing DirtyExit")
        expect(test_job.error).to be_include(error_message)
        expect(test_job.error).to be_include("job_spec.rb:#{__LINE__ - 10}")
      end

      it "includes the DirtyExit message if no process_status" do
        test_error = Resque::DirtyExit.new("Testing DirtyExit simple test")

        job.start
        job.failed(test_error)

        expect(test_job.error).to eq "Testing DirtyExit simple test"
      end

      it "sets the error to the exception message" do
        job.start
        job.failed(StandardError.new(error_message))

        expect(test_job.error).to eq error_message
      end

      it "sets succeeded? to false" do
        job.start
        job.failed(StandardError.new(error_message))

        expect(test_job.succeeded?).to be_falsey
      end

      it "increments the total failed counter" do
        job.start

        expect { job.failed(StandardError.new(error_message)) }.
            to change { test_job.total_failed_jobs }.by 1
      end

      it "finishes the job" do
        job.start
        job.failed(StandardError.new(error_message))

        expect(test_job.finished?).to be_truthy
      end
    end

    describe "cancel" do
      it "sets the error to something" do
        job.start
        job.cancel

        expect(test_job.error).not_to be_blank
      end

      it "sets succeeded? to false" do
        job.start
        job.cancel

        expect(test_job.succeeded?).to be_falsey
      end

      it "increments the total failed counter" do
        job.start

        expect { job.cancel }.
            to change { test_job.total_failed_jobs }.by 1
      end

      it "finishes the job" do
        job.start
        job.cancel

        expect(test_job.finished?).to be_truthy
      end
    end

    describe "retry" do
      it "does not retry an invalid class" do
        bad_job = Resque::Plugins::JobHistory::Job.new "InvalidCustomHistoryLengthJob", job_id
        bad_job.start(*test_args)
        bad_job.finish

        expect(Resque).not_to receive(:enqueue)

        bad_job.retry
      end

      it "retries the job with the jobs initial arguments" do
        job.start(*test_args)
        job.finish

        expect(Resque).to receive(:enqueue).with(CustomHistoryLengthJob, *test_args)

        job.retry
      end
    end

    describe "purge" do
      it "deletes the job from the list of running jobs" do
        job.start

        expect { job.purge }.to change { test_job.running_jobs.num_jobs }.by(-1)
      end

      it "deletes the job from the list of linear jobs" do
        job.start

        expect { job.purge }.to change { test_job.linear_jobs.num_jobs }.by(-1)
      end

      it "cancels a running job" do
        job.start

        expect(job).to receive(:cancel).and_return nil

        expect { job.purge }.to change { test_job.running_jobs.num_jobs }.by(-1)
      end

      it "deletes the job from the list of finished jobs" do
        job.start
        job.finish

        expect { job.purge }.to change { test_job.finished_jobs.num_jobs }.by(-1)
      end

      it "deletes job data" do
        job.start(*test_args)

        job.purge

        expect(test_job.start_time).to be_nil
        expect(test_job.end_time).to be_nil
        expect(test_job.error).to be_nil
        expect(test_job.args).to be_blank
      end
    end
  end

  describe "#clean_old_running_jobs" do
    it "cleans out old jobs based on the purge_age" do
      purge_jobs = Array.new(10).map do
        Timecop.travel(2.hours.ago) do
          job = Resque::Plugins::JobHistory::Job.new("CustomPurgeAgeJob", SecureRandom.uuid)
          job.start
          job
        end
      end

      keep_jobs = Array.new(10).map do
        Timecop.travel(30.minutes.ago) do
          job = Resque::Plugins::JobHistory::Job.new("CustomPurgeAgeJob", SecureRandom.uuid)
          job.start
          job
        end
      end

      purge_job = Resque::Plugins::JobHistory::Job.new "CustomPurgeAgeJob", job_id
      purge_job.clean_old_running_jobs

      test_purge_job = Resque::Plugins::JobHistory::Job.new "CustomPurgeAgeJob", job_id

      expect(test_purge_job.running_jobs.num_jobs).to eq 10
      expect(test_purge_job.running_jobs.job_ids.sort).to eq(keep_jobs.map(&:job_id).sort)
      purge_jobs.each do |purged_job|
        expect(test_purge_job.running_jobs.job_ids).not_to be_include(purged_job.job_id)
      end
    end
  end

  describe "#safe_purge" do
    it "does not purge the job if it is only in the finished list" do
      job.start
      job.finish
      job.running_jobs.remove_job(job_id)
      job.linear_jobs.remove_job(job_id)

      expect(test_job.finished_jobs.latest_job.job_id).to eq job.job_id

      job.safe_purge

      expect(test_job.finished_jobs.latest_job.job_id).to eq job.job_id
    end

    it "does not purge the job if it is only in the running list" do
      job.start
      job.finished_jobs.remove_job(job_id)
      job.linear_jobs.remove_job(job_id)

      expect(test_job.running_jobs.latest_job.job_id).to eq job.job_id

      job.safe_purge

      expect(test_job.running_jobs.latest_job.job_id).to eq job.job_id
    end

    it "does not purge the job if it is only in the lineear list" do
      job.start
      job.finished_jobs.remove_job(job_id)
      job.running_jobs.remove_job(job_id)

      expect(test_job.linear_jobs.latest_job.job_id).to eq job.job_id

      job.safe_purge

      expect(test_job.linear_jobs.latest_job.job_id).to eq job.job_id
    end

    it "does purge the job if it is not in any of the three lists" do
      job.start
      job.linear_jobs.remove_job(job_id)
      job.finished_jobs.remove_job(job_id)
      job.running_jobs.remove_job(job_id)

      job.safe_purge

      expect(test_job.start_time).not_to be
    end
  end
end
