# frozen_string_literal: true

class JobSummaryBuilder
  attr_reader :running_list,
              :finished_list,
              :failed_list,
              :canceled_list,
              :max_concurrent,
              :last_run,
              :total_run,
              :total_finished,
              :total_failed,
              :summaries

  def build_job_summaries(all_job_class_names)
    @summaries ||= all_job_class_names.map do |class_name|
      build_summary(class_name)
    end
  end

  def build_summary(class_name)
    build_job_lists(class_name)

    summary_hash(class_name)
  end

  def summary_hash(class_name)
    { class_name:          class_name,
      class_name_valid:    valid_class?(class_name),
      running_jobs:        total_running_in_list,
      finished_jobs:       total_finished_in_list,
      total_run_jobs:      total_run,
      total_finished_jobs: total_finished,
      max_concurrent_jobs: max_concurrent,
      total_failed_jobs:   total_failed,
      last_run:            last_run }
  end

  def valid_class?(class_name)
    class_name.constantize
    true
  rescue StandardError
    false
  end

  def setup_stats(class_name)
    setup_total_run_jobs(class_name)
    setup_total_finished_jobs(class_name)
    setup_total_failed_jobs(class_name)
    setup_max_concurrent(class_name)
  end

  def setup_max_concurrent(class_name)
    @max_concurrent = rand(11..15)

    jobs = Array.new(max_concurrent).map do
      build_running_job(class_name)
    end

    jobs.each do |job|
      job.purge

      @total_failed   += 1
      @total_finished += 1
    end
  end

  def total_finished_in_list
    [finished_list.length + failed_list.length + canceled_list.length, last_run.send(:class_history_len)].min
  end

  def total_running_in_list
    [running_list.length, last_run.send(:class_history_len)].min
  end

  def setup_total_run_jobs(_class_name)
    @total_run = 0
  end

  def setup_total_finished_jobs(class_name)
    @total_finished = 0

    Array.new(rand(0..10)) { build_finished_job(class_name).purge }
  end

  def setup_total_failed_jobs(class_name)
    @total_failed = 0

    Array.new(rand(0..5)) { build_canceled_job(class_name).purge }
    Array.new(rand(0..5)) { build_failed_job(class_name).purge }
  end

  def build_job_lists(class_name)
    setup_stats(class_name)

    build_running_list(class_name)
    build_finished_list(class_name)
    build_failed_list(class_name)
    build_canceled_list(class_name)

    @last_run = running_list.last || canceled_list.last
    last_run.redis.set("job_history.#{class_name}.max_jobs", max_concurrent)
  end

  def build_canceled_list(class_name)
    @canceled_list = Array.new(rand(5..10)) { build_canceled_job(class_name) }
  end

  def build_failed_list(class_name)
    @failed_list = Array.new(rand(5..10)) { build_failed_job(class_name) }
  end

  def build_finished_list(class_name)
    @finished_list = Array.new(rand(5..10)) { build_finished_job(class_name) }
  end

  def build_running_list(class_name)
    @running_list = if [true, false].sample
                      Array.new(rand(5..10)) { build_running_job(class_name) }
                    else
                      []
                    end
  end

  def build_canceled_job(class_name)
    job = build_running_job(class_name)

    Timecop.freeze(job.start_time + rand(1..24 * 60 * 60).seconds) { job.cancel }
    @total_finished += 1
    @total_failed   += 1

    job
  end

  def build_failed_job(class_name)
    job = build_running_job(class_name)

    Timecop.freeze(job.start_time + rand(1..24 * 60 * 60).seconds) do
      job.failed(StandardError.new("Something happened."))
    end
    @total_finished += 1
    @total_failed   += 1

    job
  end

  def build_finished_job(class_name)
    job = build_running_job(class_name)

    Timecop.freeze(job.start_time + rand(1..24 * 60 * 60).seconds) { job.finish }
    @total_finished += 1

    job
  end

  def build_running_job(class_name)
    job        = Resque::Plugins::JobHistory::Job.new(class_name, SecureRandom.uuid)
    start_time = rand((24 * 60 * 60)..(100 * 24 * 60 * 60)).seconds.ago

    Timecop.freeze(start_time) { job.start }
    @total_run += 1

    job
  end
end
