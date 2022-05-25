# frozen_string_literal: true

require "rails_helper"

RSpec.describe "job_details.erb" do
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
  let(:job_id) { SecureRandom.uuid }
  let(:job) { Resque::Plugins::JobHistory::Job.new("CustomPageSizeJob", job_id) }

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  before(:each) do
    job.start(*test_args)
    job.failed(StandardError.new("Sample Failure"))
  end

  it "should respond to /job_history/cancel_job" do
    job.purge
    job.start

    post "/job_history/cancel_job?class_name=CustomPageSizeJob&job_id=#{job_id}"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).
        to match(%r{job_history/job_details\?class_name=CustomPageSizeJob&job_id=#{job_id}$})

    job.send(:reset)
    expect(job.finished?).to be_truthy
  end

  it "should respond to /job_history/delete_job" do
    post "/job_history/delete_job?class_name=CustomPageSizeJob&job_id=#{job_id}&job_id=#{job_id}"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).
        to match(%r{job_history/job_class_details\?class_name=CustomPageSizeJob$})

    get "/job_history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok
    expect(last_response.body).not_to include(job_id)
  end

  it "should respond to /job_history/retry_job" do
    expect(Resque).to receive(:enqueue).with(CustomPageSizeJob, *test_args).and_call_original

    post "/job_history/retry_job?class_name=CustomPageSizeJob&job_id=#{job_id}&job_id=#{job_id}"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).
        to match(%r{job_history/job_class_details\?class_name=CustomPageSizeJob$})

    get "/job_history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok
    expect(last_response.body).to include(job_id)
    expect(last_response.body.scan("<tr>").count).to eq 9
  end

  it "should respond to /job_history/job_details" do
    get "/job_history/job_details?class_name=CustomPageSizeJob&job_id=#{job_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("CustomPageSizeJob")

    expect(last_response.body).to match %r{Job History(\n *)?</a>}
    expect(last_response.body).to match %r{CustomPageSizeJob(\n *)?</a>}

    expect(last_response.body).
        not_to match %r{action="/job_history/cancel_job\?class_name=CustomPageSizeJob&job_id=#{job_id}"}
    expect(last_response.body).
        to match %r{action="/job_history/delete_job\?class_name=CustomPageSizeJob&job_id=#{job_id}"}
    expect(last_response.body).
        to match %r{action="/job_history/retry_job\?class_name=CustomPageSizeJob&job_id=#{job_id}"}

    expect(last_response.body).to match(%r{Started(\n *)</td>})
    expect(last_response.body).to match(%r{Duration(\n *)</td>})
    expect(last_response.body).to match(%r{Params(\n *)</td>})
    expect(last_response.body).to match(%r{Error(\n *)</td>})

    expect(last_response.body).to be_include("job_history/job_class_details?class_name=CustomPageSizeJob\"")
    expect(last_response.body).to be_include("job_history\"")
  end

  it "styles a job if it fails" do
    get "/job_history/job_details?class_name=CustomPageSizeJob&job_id=#{job_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to match(/class="job_history_error"/)
  end

  it "shows the parameters for the jobs" do
    get "/job_history/job_details?class_name=CustomPageSizeJob&job_id=#{job_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("".html_safe + test_args.to_yaml)
  end

  it "includes the error message" do
    get "/job_history/job_details?class_name=CustomPageSizeJob&job_id=#{job_id}"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("Sample Failure")
  end

  it "allows you to cancel a job no longer running" do
    job.purge
    job.start

    get "/job_history/job_details?class_name=CustomPageSizeJob&job_id=#{job_id}"

    expect(last_response).to be_ok

    expect(last_response.body).
        to match %r{action="/job_history/cancel_job\?class_name=CustomPageSizeJob&job_id=#{job_id}"}
  end
end
