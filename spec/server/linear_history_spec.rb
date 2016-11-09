# frozen_string_literal: true

require "rails_helper"

RSpec.describe "linear_history.erb" do
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
    page_size = Resque::Plugins::JobHistory::HistoryDetails.linear_page_size

    begin
      example_proxy.call
    ensure
      Resque::Plugins::JobHistory::HistoryDetails.linear_page_size = page_size
    end
  end

  before(:each) do
    Resque::Plugins::JobHistory::HistoryDetails.linear_page_size = 10

    Array.new(29) do |index|
      if index == 27
        job = Resque::Plugins::JobHistory::Job.new("CustomPageSizeJob", SecureRandom.uuid)
        job.start(*test_args)
        job.failed(StandardError.new("Sample Failure"))
      else
        Resque.enqueue(CustomPageSizeJob, *test_args)
      end
      Resque::Plugins::JobHistory::Job.new("CustomPageSizeJob", SecureRandom.uuid).start(*test_args)
      Resque.enqueue(BasicJob, *test_args)
      Resque::Plugins::JobHistory::Job.new("BasicJob", SecureRandom.uuid).start(*test_args)
    end
  end

  it "should respond to /job history/purge_linear_history" do
    post "/job%20history/purge_linear_history"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).to match(/job history$/)

    get "/job%20history"

    expect(last_response.body.scan("<tr>").count).to eq 3
  end

  it "should respond to /job history/linear_history" do
    get "/job%20history/linear_history"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("Linear History")

    expect(last_response.body).to match %r{Job History(\n *)?</a>}

    expect(last_response.body).
        to match %r{action="/job history/purge_linear_history"}

    expect(last_response.body).to be_include "Class</th>"
    expect(last_response.body).to be_include "Started</th>"
    expect(last_response.body).to be_include "Duration</th>"
    expect(last_response.body).to be_include "Parameters</th>"
    expect(last_response.body).to be_include "Error</th>"

    expect(last_response.body).to be_include("job history\"")
    expect(last_response.body.scan("<tr").count).to eq 11
  end

  it "styles a job if it fails" do
    get "/job%20history/linear_history"

    expect(last_response).to be_ok

    expect(last_response.body).to match(/class="job_history_error"/)
  end

  it "shows the parameters for the jobs" do
    get "/job%20history/linear_history"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("".html_safe + test_args.to_yaml)
  end

  it "includes the error message" do
    get "/job%20history/linear_history"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("Sample Failure")
  end

  it "allows a search of the linear history" do
    get "/job%20history/linear_history"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{action="/job history/search_linear_history"})
  end
end
