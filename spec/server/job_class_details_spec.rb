# frozen_string_literal: true

require "rails_helper"

RSpec.describe "job_class_details.erb" do
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

  before(:each) do
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

  it "should respond to /job history/purge_class" do
    post "/job%20history/purge_class?class_name=CustomPageSizeJob"

    expect(last_response).to be_redirect
    expect(last_response.header["Location"]).to match(/job history$/)

    get "/job%20history"

    expect(last_response).to be_ok
    expect(last_response.body.scan("<tr>").count).to eq 3
  end

  it "should respond to /job history/job_class_details" do
    get "/job%20history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("CustomPageSizeJob")

    expect(last_response.body).to match %r{Job History(\n *)?</a>}
    expect(last_response.body).to match %r{action="/job history/purge_class\?class_name=CustomPageSizeJob"}

    expect(last_response.body).to match(%r{Running jobs(\n *)</td>})
    expect(last_response.body).to match(%r{Total jobs run(\n *)</td>})
    expect(last_response.body).to match(%r{Total jobs finished(\n *)</td>})
    expect(last_response.body).to match(%r{Total jobs failed(\n *)</td>})
    expect(last_response.body).to match(%r{Total jobs in history(\n *)</td>})
    expect(last_response.body).to match(%r{Maximum number of consecutive jobs seen(\n *)</td>})
    expect(last_response.body).to match(%r{Is still valid job(\n *)</td>})

    expect(last_response.body.scan("<tr").count).to eq 29

    expect(last_response.body).to be_include("job_details?class_name=CustomPageSizeJob&job_id=")
  end

  it "pages running jobs" do
    get "/job%20history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok

    expect(last_response.body).
        to match(%r{/job history/job_class_details\?class_name=CustomPageSizeJob.*&running_page_num=2})
    expect(last_response.body).
        to match(%r{/job history/job_class_details\?class_name=CustomPageSizeJob.*&running_page_num=3})
    expect(last_response.body).
        not_to match(%r{/job history/job_class_details\?class_name=CustomPageSizeJob.*&running_page_num=4})
  end

  it "pages finished jobs" do
    get "/job%20history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok

    expect(last_response.body).
        to match(%r{/job history/job_class_details\?class_name=CustomPageSizeJob.*&finished_page_num=2})
    expect(last_response.body).
        to match(%r{/job history/job_class_details\?class_name=CustomPageSizeJob.*&finished_page_num=3})
    expect(last_response.body).
        not_to match(%r{/job history/job_class_details\?class_name=CustomPageSizeJob.*&finished_page_num=4})
  end

  it "styles a job if it fails" do
    get "/job%20history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok

    expect(last_response.body).to match(/class="job_history_error"/)
  end

  it "shows the parameters for the jobs" do
    get "/job%20history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("".html_safe + test_args.to_yaml)
  end

  it "includes the error message" do
    get "/job%20history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok

    expect(last_response.body).to be_include("Sample Failure")
  end

  it "allows a search of this class" do
    get "/job%20history/job_class_details?class_name=CustomPageSizeJob"

    expect(last_response).to be_ok

    expect(last_response.body).to match(%r{action="/job history/search_job"})
    expect(last_response.body).to match(/name="job_class_name" value="CustomPageSizeJob"/)
  end
end
