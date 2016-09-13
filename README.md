resque-job_history
==================

[github.com/RealNobody/resque-job_history](https://github.com/RealNobody/resque-job_history)

Description
-----------

JobHistory is a [Resque](https://github.com/defunkt/resque) plugin which
saves a history of runs for individual jobs as they are performed.  It then
allows you to review the runs and see when they were performed, what
parameters were passed into the job, and if it was successful or not.

The history of the job runs are kept for each job separately allowing you
to keep a larger or smaller history for each job as is appropriate for
each job.

A linear view of job executions is also available to allow you to see how
jobs are executed relative to other jobs more easily.

Installation
------------

Add the gem to your Gemfile:

```
gem "resque-job_history"
```

Usage
----

###Tracking histories

Simply include the JobHistory class in the class that is enqueued to Resque:

```
include Resque::Plugins::JobHistory
```

###Server extension

To add the server tab and views to Resqueue, add include the file
`resque/job_history_server` to your `routes.rb` file.

```
require "resque/job_history_server"
```

Options
-------

###Job Options

You can customize a number of options for each job that the `JobHistory`
module is included in.

```
class MyResqueJob
  include Resque::Plugins::JobHistory

  # Set class instance variables to set values for options...
  @job_history_len = 200
end
```

**`job_history_len`**

This is the number of histories to be kept for this class.  This number
is used for both the list of running and finished jobs.  As new jobs are
added to the list of running or finished jobs each list will independently
the oldest job from the list if the number of jobs exceeds this value.

Usage:

```
@job_history_len = 200
```

**`purge_age`**

If something happens and the execution of a job is interrupted, the system
will not run callbacks indicating that a job has finished or been canceled.
In such a case, the system cannot know to remove a job from the running list.

To prevent this from happening, when the running list becomes full, any job
that is older than `purge_age` will be canceled under the assumption that
the job is not actually running.

Usage:

```
@purge_age = 24.hours
```

**`exclude_from_linear_history`**

If this is set to true, then the job will not appear in the linear history.

Usage:

```
@exclude_from_linear_history = false
```

**`page_size`**

This is the default page size for the list of running and finished jobs
for the job.

Usage:

```
@page_size = 25
```


###Global Options

You can customize some of the view options for the server if you would like.

**`max_linear_job`**

This is the maximum number of jobs that are kept in the linear history.
The linear history is kept separately from job histories so limits on the
number of histories for a job do not affect the linear history.  A job
can be excluded entirely from the linear history if you want, but if it
is included, then every instance of that job will show in the linear history
even if this exceeds the number of instance that show up for the class.

Usage:

```
Resque::Plugins::JobHistory::HistoryDetails.max_linear_job = 500
```

**`linear_page_size`**

This is the default page size that is used when displaying the linear
history.

Usage:

```
Resque::Plugins::JobHistory::HistoryDetails.linear_page_size = 25
```

**`class_list_page_size`**

This is the default page size that is used when displaying the running
and finished jobs for a job.

Usage:

```
Resque::Plugins::JobHistory::HistoryDetails.class_list_page_size = 25
```

Server Navigation
-----------------

####Jobs and a quick summary

![Job History](https://raw.githubusercontent.com/RealNobody/resque-job_history/master/read_me/job_history_page.png)

####Linear Histories

![Job History](https://raw.githubusercontent.com/RealNobody/resque-job_history/master/read_me/linear_history_page.png)

####History of a single Job

![Job History](https://raw.githubusercontent.com/RealNobody/resque-job_history/master/read_me/class_details.png)

####An individual run

![Job History](https://raw.githubusercontent.com/RealNobody/resque-job_history/master/read_me/job_details.png)


Accessing Histories Progamatically
----------------------------------

You can easily access the list of histories programatically.

```
class MyJob
  include Resque::Plugins::JobHistory
end

histories = MyJob.job_history
```

Some useful methods:

The history for a job includes these useful methods:
* running_jobs - A list of the currently running jobs.
* finished_jobs - A list of all finished jobs.
* linear_jobs - A linear list of all jobs for all classes.
* max_concurrent_jobs - The maximum number of concurrently running instances
  of the job.
* total_failed_jobs - The total number of times the running of this job
  failed for some reason.
* num_running_jobs - The number of jobs in the running_jobs list.
* num_finished_jobs - The number of jobs in the finished_jobs list.
* total_run_jobs - The number of jobs that have been placed in the
  running jobs list.
* last_run - The most recent Job run that was enqueued.

Lists of jobs include these useful methods:
* paged_jobs - A paged list of jobs.
* jobs - A list of jobs (you can specify sub-ranges).
* num_jobs - The total number of jobs in the list.
* total - The total number of times a job has been in this list.
* latest_job - The most recently added job.

Jobs include these useful methods:
* class_name - The name of the Job that was enqueued.
* job_id - A unique identifier for the job.
* start_time - The time the job started.
* end_tiem - The time the job ended.
* duration - The duration of the job (if the job is running, the duration of
  the job so far.)
* finished? - Whether or not the job is finished.
* succeeded? - If the job is still running, or finished successfully.
* args - The arguments for the job.
* error - The error message if the job failed.
* cancel - "stop" the job manually.
* retry - Retry the job.
* purge - Remove the job from the history.

The JobList is a list of all of the jobs whose histories have been recorded.

```
job_list = Resque::Plugins::JobHistory::JobList.new
```

It has these useful functions:
* job_summaries - A list of all of the Jobs that have been run.
  The summaries are the histories of each job and include the methods
  detailed for a history.
* job_classes - An array of strings of the names of all the classes
  that have been enqueued and their history recorded.
* job_details - Returns the job history for a single class.

The Cleaner is a utility class used to clean up `Resis`.

```
Resque::Plugins::JobHistory::Cleaner.purge_all_jobs
```

The Cleaner class includes these useful functions:
* purge_all_jobs - Delete all histories.
* purge_class - Delete the history for a single Job.
* purge_invalid_jobs - Delete the history for any Job that cannot
  be instantiated.
* clean_all_old_running_jobs - For all Jobs, `cancel` any running job
  that exceds its `purge_age`.
* fixup_all_keys - Cleanup any keys for jobs that are not in a running,
  finished or linear list.
* fixup_job_keys - Cleanup any keys for a particular Job class.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
