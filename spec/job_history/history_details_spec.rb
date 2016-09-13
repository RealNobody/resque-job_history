# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::JobHistory::HistoryDetails do
  let(:history_details) { Resque::Plugins::JobHistory::HistoryDetails.new "BasicJob" }

  it "namespaces redis" do
    expect(history_details.redis).to be_a(Redis::Namespace)
  end

  it "has a base key name" do
    expect(history_details.class.job_history_key).to eq "job_history"
  end

  it "has a base class key name" do
    expect(history_details.job_history_base_key).to eq "job_history.BasicJob"
  end

  it "has running_jobs" do
    expect(history_details.running_jobs).to be_a Resque::Plugins::JobHistory::HistoryList
  end

  it "has finished_jobs" do
    expect(history_details.finished_jobs).to be_a Resque::Plugins::JobHistory::HistoryList
  end

  it "returns max_concurrent_jobs" do
    history_details.redis.set("job_history.BasicJob.max_jobs", -1)
    expect(history_details.max_concurrent_jobs).to eq(-1)
  end

  it "returns total_failed_jobs" do
    history_details.redis.set("job_history.BasicJob.total_failed", -1)
    expect(history_details.total_failed_jobs).to eq(-1)
  end

  it "returns class_name_valid?" do
    expect(history_details.class_name_valid?).to be_truthy
  end

  it "returns class_name_valid? for an invalid class" do
    expect(Resque::Plugins::JobHistory::HistoryDetails.new("InvalidBasicJob").class_name_valid?).
        to be_falsey
  end

  describe "class_list_page_size" do
    around(:each) do |example_proxy|
      page_size = Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size

      begin
        example_proxy.call
      ensure
        Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size = page_size
      end
    end

    it "returns the PAGE_SIZE by default" do
      expect(Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size).
          to eq Resque::Plugins::JobHistory::PAGE_SIZE
    end

    it "allows you to set any value you want" do
      page_size = rand(10..20)

      Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size = page_size

      expect(Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size).to eq page_size
    end
  end
end
