package Qless;
use strict; use warnings;
use Qless::Client;
our $VERSION = '0.01';



1;

__END__

=head1 NAME

Qless - perl bind for Qless job queueing system

=head1 DESCRIPTION

Qless is a powerful L<Redis|http://redis.io>-based job queueing system inspired by L<resque|https://github.com/defunkt/resque#readme>, but built on a collection of Lua scripts, maintained in the L<qless-core|https://github.com/seomoz/qless-core> repo.

=head2 Philosophy and Nomenclature

A job is a unit of work identified by a job id or jid. A queue can contain several jobs that are scheduled to be run at a certain time, several jobs that are waiting to run, and jobs that are currently running. A worker is a process on a host, identified uniquely, that asks for jobs from the queue, performs some process associated with that job, and then marks it as complete. When it's completed, it can be put into another queue.

Jobs can only be in one queue at a time. That queue is whatever queue they were last put in. So if a worker is working on a job, and you move it, the worker's request to complete the job will be ignored.

A job can be canceled, which means it disappears into the ether, and we'll never pay it any mind every again. A job can be dropped, which is when a worker fails to heartbeat or complete the job in a timely fashion, or a job can be failed, which is when a host recognizes some systematically problematic state about the job. A worker should only fail a job if the error is likely not a transient one; otherwise, that worker should just drop it and let the system reclaim it.

=head2 Features

1. B<Jobs don't get dropped on the floor> -- Sometimes workers drop jobs. Qless automatically picks them back up and gives them to another worker

2. B<Tagging / Tracking> -- Some jobs are more interesting than others. Track those jobs to get updates on their progress. Tag jobs with meaningful identifiers to find them quickly in the UI.

3. B<Job Dependencies> -- One job might need to wait for another job to complete

4. B<Stats> -- qless automatically keeps statistics about how long jobs wait to be processed and how long they take to be processed. Currently, we keep track of the count, mean, standard deviation, and a histogram of these times.

5. B<Job data is stored temporarily> -- Job info sticks around for a configurable amount of time so you can still look back on a job's history, data, etc.

6. B<Priority> -- Jobs with the same priority get popped in the order they were inserted; a higher priority means that it gets popped faster

7. B<Retry logic> -- Every job has a number of retries associated with it, which are renewed when it is put into a new queue or completed. If a job is repeatedly dropped, then it is presumed to be problematic, and is automatically failed.

8. B<Web App> -- With the advent of a Ruby client, there is a Sinatra-based web app that gives you control over certain operational issues (I<TDB - porting to perl PSGI app>)

9. B<Scheduled Work> -- Until a job waits for a specified delay (defaults to 0), jobs cannot be popped by workers

10. B<Recurring Jobs> -- Scheduling's all well and good, but we also support jobs that need to recur periodically.

11. B<Notifications> -- Tracked jobs emit events on pubsub channels as they get completed, failed, put, popped, etc. Use these events to get notified of progress on jobs you're interested in. B<NOT IMPLEMENTED>

Interest piqued? Then read on!

=head2 Installation

Install from CPAN:

C<sudo cpan Qless>

Alternatively, install qless-perl from source by checking it out from repository:

    hg clone ssh://hg@bitbucket.org/nuclon/qless-perl
    cd qless-perl
    perl Makefile.PL
    sudo make install

=head2 Enqueing Jobs

=head2 Running a Worker

=head2 Job Dependencies

=head2 Priority

=head2 Scheduled Jobs

=head2 Recurring Jobs

=head2 Configuration Options

=head2 Tagging / Tracking

=head2 Notifications

=head2 Retries

=head2 Pop

=head2 Heartbeating

=head2 Stats

=head2 Time

=head2 Ensuring Job Uniqueness

=head2 Setting Default Job Options

=head2 Testing Jobs

=head1 DEVELOPMENT

=head2 Repository

qless-perl: L<https://bitbucket.org/nuclon/qless-perl|https://bitbucket.org/nuclon/qless-perl>

qless-core: L<https://github.com/seomoz/qless-core|https://github.com/seomoz/qless-core>

=head1 AUTHOR

qless and qless-core - SEOmoz

=cut
