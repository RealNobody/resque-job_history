# frozen_string_literal: true

require "rails_helper"

RSpec.describe "job_history.erb" do
  let(:all_valid_jobs) do
    [BasicJob,
     CustomHistoryLengthJob,
     CustomPageSizeJob,
     CustomPurgeAgeJob,
     ExcludeLiniearHistoryJob]
  end
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

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  around(:each) do |example_proxy|
    page_size = Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size

    begin
      example_proxy.call
    ensure
      Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size = page_size
    end
  end

  before(:each) do
    Resque.enqueue(BasicJob, test_args)
  end

  it "should respond to /job history/purge_all" do
    post "/job%20history/purge_all"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).to match(/job history$/)

    get "/job%20history"

    expect(last_response).to be_ok
    expect(last_response.body.scan("<tr>").count).to eq 1
  end

  it "should respond to /job history" do
    get "/job%20history"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("Job Classes")

    expect(last_response.body).to match %r{Linear History(\n *)?</a>}
    expect(last_response.body).to match %r{action="/job history/purge_all"}

    expect(last_response.body).to match(/sort=class_name">(\n *)?Class name/)
    expect(last_response.body).to match(/sort=num_running_jobs">(\n *)?Running/)
    expect(last_response.body).to match(/sort=total_run_jobs">(\n *)?Total Run/)
    expect(last_response.body).to match(/sort=total_finished_jobs">(\n *)?Finished/)
    expect(last_response.body).to match(/sort=total_failed_jobs">(\n *)?Failed/)
    expect(last_response.body).to match(/sort=start_time">(\n *)?Last Run Start/)
    expect(last_response.body).to match(/sort=duration">(\n *)?Last Run Duration/)
    expect(last_response.body).to match(/sort=success">(\n *)?Last Run successful/)

    expect(last_response.body.scan("<tr>").count).to eq 2

    expect(last_response.body).to be_include("job_class_details?class_name=BasicJob")
  end

  it "pages jobs" do
    Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size = 2

    all_valid_jobs.each do |job|
      Resque.enqueue(job, test_args)
    end

    get "/job%20history"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{href="/job history?.*page_num=2})
    expect(last_response.body).to match(%r{href="/job history?.*page_num=3})
    expect(last_response.body).not_to match(%r{href="/job history?.*page_num=4})
  end

  it "styles a job if it fails" do
    expect { Resque.enqueue(FailingJob, test_args) }.to raise_error StandardError

    get "/job%20history"

    expect(last_response).to be_ok

    expect(last_response.body).to match(/class="job_history_error"/)
  end

  it "allows a search of all classes" do
    get "/job%20history"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{action="/job history/search_all"})
  end
end
