# frozen_string_literal: true

class FailingJob < BasicJob
  def self.perform(*args)
    super(*args)

    raise "This job failed"
  end
end
