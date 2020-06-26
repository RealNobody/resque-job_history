# frozen_string_literal: true

class LinearOneJob < BasicJob
  @job_history_len = 10
end

class LinearTwoJob < BasicJob
  @job_history_len = 10
end

class LinearThreeJob < BasicJob
  @job_history_len = 10
end
