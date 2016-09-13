# frozen_string_literal: true

class JobSummarySortTester
  attr_reader :tester

  def initialize(tester)
    @tester = tester
  end

  def test_ascending(job_list, field_name)
    prev_value = ""
    Array.new(4) do |index|
      jobs = get_jobs(job_list, field_name, "asc", index)

      jobs.each do |job|
        unless prev_value.blank?
          tester.expect(job.public_send(field_name.to_sym)).to tester.be >= prev_value
        end

        prev_value = job.public_send(field_name.to_sym)
      end
    end
  end

  def test_last_ascending(job_list, field_name, method_name)
    prev_value = ""
    Array.new(4) do |index|
      jobs = get_jobs(job_list, field_name, "asc", index)

      jobs.each do |job|
        unless prev_value.blank?
          tester.expect(job.last_run.send(method_name)).to tester.be >= prev_value
        end

        prev_value = job.last_run.send(method_name)
      end
    end
  end

  def test_descending(job_list, field_name)
    prev_value = ""
    Array.new(4) do |index|
      jobs = get_jobs(job_list, field_name, "desc", index)

      jobs.each do |job|
        unless prev_value.blank?
          tester.expect(job.public_send(field_name.to_sym)).to tester.be <= prev_value
        end

        prev_value = job.public_send(field_name.to_sym)
      end
    end
  end

  def get_jobs(job_list, field_name, direction, page_number)
    job_list.job_summaries(field_name, direction, page_number + 1, 2)
  end

  def test_last_descending(job_list, field_name, method_name)
    prev_value = ""
    Array.new(4) do |index|
      jobs = get_jobs(job_list, field_name, "desc", index)

      jobs.each do |job|
        unless prev_value.blank?
          tester.expect(job.last_run.send(method_name)).to tester.be <= prev_value
        end

        prev_value = job.last_run.send(method_name)
      end
    end
  end

  def test_summaries(class_name, expected_job_summaries)
    job_list         = Resque::Plugins::JobHistory::JobList.new
    actual_summary   = job_list.job_details(class_name)
    expected_summary = find_expected_summary(class_name, expected_job_summaries)

    test_summary_key_values(actual_summary, expected_summary)

    tester.expect(actual_summary.last_run.job_id).
        to tester.eq expected_summary[:last_run].job_id
  end

  def find_expected_summary(class_name, expected_job_summaries)
    expected_job_summaries.detect { |summary| summary[:class_name] == class_name }
  end

  def test_summary_key_values(actual_summary, expected_summary)
    (expected_summary.keys - [:last_run]).each do |key|
      tester.expect(actual_summary.public_send(key.to_sym)).to tester.eq expected_summary[key]
    end
  end
end
