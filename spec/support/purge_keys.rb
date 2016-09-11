# frozen_string_literal: true

RSpec.configure do |configuration|
  configuration.before(:each) do
    Resque::Plugins::JobHistory::Cleaner.purge_all_jobs
  end

  configuration.after(:each) do
    Resque::Plugins::JobHistory::Cleaner.purge_all_jobs
  end
end
