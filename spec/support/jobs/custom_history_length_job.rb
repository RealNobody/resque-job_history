# frozen_string_literal: true

require "resque/plugins/compressible"

class CustomHistoryLengthJob < BasicJob
  @job_history_len = 50

  extend Resque::Plugins::Compressible
end
