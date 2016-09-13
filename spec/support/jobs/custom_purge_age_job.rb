# frozen_string_literal: true

class CustomPurgeAgeJob < BasicJob
  @purge_jobs_after = 1.hour
end
