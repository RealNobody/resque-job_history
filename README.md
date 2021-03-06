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

```Ruby
gem "resque-job_history"
```

Usage
----

###Tracking histories

Simply include the JobHistory class in the class that is enqueued to Resque:

```Ruby
include Resque::Plugins::JobHistory
```

###Server extension

To add the server tab and views to Resqueue, add include the file
`resque/job_history_server` to your `routes.rb` file.

```Ruby
require "resque/job_history_server"
```

Options
-------

###Job Options

You can customize a number of options for each job that the `JobHistory`
module is included in.

```Ruby
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

```Ruby
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

```Ruby
@purge_age = 24.hours
```

**`exclude_from_linear_history`**

If this is set to true, then the job will not appear in the linear history.

Usage:

```Ruby
@exclude_from_linear_history = false
```

**`page_size`**

This is the default page size for the list of running and finished jobs
for the job.

Usage:

```Ruby
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

```Ruby
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

![Job History](https://raw.githubusercontent.com/RealNobody/resque-job_history/master/read_me/class_details_page.png)

####An individual run

![Job History](https://raw.githubusercontent.com/RealNobody/resque-job_history/master/read_me/job_details_page.png)


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

JobSearch is a utility class that you can use to search the histories.  You
can access the search through the front-end, or you can use it
programatically to find histories.

When used programatically, you pass in options through a hash.  The options
for the hash are:

* :search_type - String - Requried - The type of search to be performed.
  * search_all - Search the class names and the arguments to a run.
  * search_job - Search the arguments for the runs for a specific class.
  * search_linear_history - Search the arguments for all runs in the
    linear history.
* :job_class_name - String - Required for everything other than "search_all"
* :search_for - String - The string to search for.
  * If this string is blank, only jobs with no arguments will be matched.
  * When arguments are searched, the arguments will be serialized using
    the Resque argument serializer before being searched.
* :regex_search - Boolean - Optional - If true, search_for will be interpreted as a
  regular expression.
* :case_insensitive - Boolean - Optional - If true the search will be done
  case insensitive.

The search will run for approximately 10 seconds and return whatever results
it finds during that time.

The following functions are available for your use:

* search - Perform the search.  If the search completes and has more_records?
  You can call it again to continue the search.  If you continue a previous
  search, the previous search results will NOT be cleared and any new
  results will be appended.
* more_records? - Returns true if the search stopped before it searched
  all known records.
* class_results - After search is called, this will contain a list of
  HistoryDetails objects for the classes that were found that matched the search
  criteria.
* run_results - After search is called, this will contain a list of Job
  objects that are the individual runs whose arguments matched the search
  criteria.

```Ruby
search = Resque::Plugins::JobHistory::JobSearch.
    new(search_type: "search_all",
        search_for:  "some.*regex",
        regex_search: true)

# Find all values no matter how long it takes...
search.search
search.search while search.more_records?

# Access the results.
search.class_results
search.run_results
```

# ActiveJob

A note on ActiveJob.

If ActiveJob is being used, this gem will try to accomodate the usage of ActiveJob as best it can.

As long as ActiveJob has been required before this plugin is required, `Resque::Plugins::JobHistory`
will be included in the job that ActiveJob uses with Resque to execute jobs.

Then, when this job executes a job, the arguments will be unpacked, and the history will be recorded
against the actual job being run and the arguments to that job rather than the singleton shared
ActiveJob class.

Additionally, histories will only be recorded against jobs which include
`Resque::Plugins::JobHistory`.

There is a problem with this however.  I do not think that the
`ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper` class and how the attributes are serialized
are intended to be public.  That is, the class and how it is serialized could probably change.  If
you are using this gem and ActiveJob, and it stops working, please let me know and I will update it.

If you use ActiveJob and you are not getting histories, it could be caused by the order in which
things where required.  If so, please try adding an initializer with the following code:

```Ruby
  unless ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper.included_modules.include? Resque::Plugins::JobHistory
    ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper.include Resque::Plugins::JobHistory
  end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
