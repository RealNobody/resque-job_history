# frozen_string_literal: true

require "rails_helper"

RSpec.describe "search_results.erb" do
  let(:test_jobs) { [CustomPageSizeJob, BasicJob] }
  let(:find_regex) { "Cust.*Job" }
  let(:regex_case_sensitive_val) { "Big fuzzy Custard Jobs are awesome" }
  let(:regex_case_insensitive_val) { "this is a job for custard jobs!  Up Up and Away!" }
  let(:find_string) { "CustomP" }
  let(:string_case_sensitive_val) { "Have you ever met the CustomPeople?  I have." }
  let(:string_case_insensitive_val) { "What abou the custompeople though?" }
  let!(:jobs) do
    test_jobs.map do |job_class|
      [Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
          start(regex_case_sensitive_val).finish,
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start((Faker::Lorem.words(5) + [regex_case_insensitive_val]).sample(100)),
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start(something_else: "fred", value: string_case_sensitive_val, not_value: "harold"),
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start(string_case_insensitive_val).failed(StandardError.new("failed")),
       Resque::Plugins::JobHistory::Job.new(job_class.name, SecureRandom.uuid).
           start.finish]
    end
  end

  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  Resque::Plugins::JobHistory::JobSearch::SEARCH_TYPES.each do |search_type|
    it "has the search details in the search form to redo a #{search_type} search" do
      full_settings = { search_type:      search_type,
                        job_class_name:   "CustomPageSizeJob",
                        search_for:       "some string",
                        regex_search:     true,
                        case_insensitive: true,
                        last_class_name:  "BasicJob",
                        last_job_id:      "last job id",
                        last_job_group:   "last group name" }

      job = Resque::Plugins::JobHistory::JobSearch.new(full_settings)

      post "job_history/#{search_type}", job.search_settings(true)

      expect(last_response).to be_ok

      top_form_start = last_response.body.index("<form")
      top_form       = last_response.body[top_form_start..last_response.body.index("/form>")]

      expect(top_form).to be_include("search_type\" value=\"#{search_type}")
      expect(top_form).to be_include("job_class_name\" value=\"CustomPageSizeJob")
      expect(top_form).to be_include("checkbox\" name=\"regex_search\" checked")
      expect(top_form).to be_include("checkbox\" name=\"case_insensitive\" checked")
      expect(top_form).to be_include("input type=\"submit\" value=\"Search\"")
      expect(top_form).to be_include("search_for\" value=\"some string\"")
      expect(top_form).not_to be_include("last_")

      bottom_form = last_response.body[last_response.body.index("<form", top_form_start + 20)..-1]

      expect(bottom_form).to be_include("search_type\" value=\"#{search_type}")
      expect(bottom_form).to be_include("job_class_name\" value=\"CustomPageSizeJob")
      expect(bottom_form).to be_include("regex_search\" value=\"true")
      expect(bottom_form).to be_include("case_insensitive\" value=\"true")
      expect(bottom_form).to be_include("input type=\"submit\" value=\"Continue Search\"")
      expect(bottom_form).to be_include("search_for\" value=\"some string\"")
      if search_type != "search_all"
        expect(bottom_form).to be_include("last_class_name\" value=\"BasicJob")
      end
      expect(bottom_form).to be_include("last_job_id\" value=\"last job id")
      expect(bottom_form).to be_include("last_job_group\" value=\"last group name")

      expect(last_response.body).to be_include("The search took too long and was stopped.")
    end
  end

  it "shows class results" do
    post "job_history/search_all",
         search_type:      "search_all",
         search_for:       find_regex,
         regex_search:     "true",
         case_insensitive: "true"

    expect(last_response.body).
        to be_include("href=\"/job_history/job_class_details?class_name=CustomPageSizeJob\"")
  end

  it "shows job results" do
    post "job_history/search_all",
         search_type:      "search_all",
         search_for:       find_regex,
         regex_search:     "true",
         case_insensitive: "true"

    expect(last_response.body).
        to be_include("href=\"/job_history/job_details?class_name=CustomPageSizeJob&job_id" \
                              "=#{jobs[0][1].job_id}\"")
  end

  it "shows no reults" do
    post "job_history/search_all",
         search_type:      "search_all",
         search_for:       "You won't ever find this.",
         regex_search:     "true",
         case_insensitive: "true"

    expect(last_response.body).to be_include("No results were found.")
  end
end
