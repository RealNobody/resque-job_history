# frozen_string_literal: true

require "rails_helper"

RSpec.describe "job_history.css" do
  include Rack::Test::Methods

  def app
    @app ||= Resque::Server.new
  end

  it "fetches the CSS file" do
    get "/job_history/public/job_history.css"

    expect(last_response).to be_ok
    expect(last_response.body).to be_include(".job_history_pagination_block {")
  end
end
