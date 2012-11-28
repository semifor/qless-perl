package TestQless::Recurring;
use base qw(TestQless);
use Test::More;
use Test::Deep;
use List::Util qw(first);

# In this test, we want to enqueue a job and make sure that
# we can get some jobs from it in the most basic way. We should
# get jobs out of the queue every _k_ seconds
sub test_recur_on : Tests {
	my $self = shift;

	$self->time_freeze;
	my $jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_recur_on'}, interval => 1800);
	is $self->{'q'}->pop->complete, 'complete';
	is $self->{'q'}->pop, undef;
	$self->time_advance(1799);
	is $self->{'q'}->pop, undef;
	$self->time_advance(2);
	my $job = $self->{'q'}->pop;
	ok $job;
	is_deeply $job->data, {test => 'test_recur_on'};
	$job->complete;
	# We should not be able to pop a second job
	is $self->{'q'}->pop, undef;
	# Let's advance almost to the next one, and then check again
	$self->time_advance(1798);
	is $self->{'q'}->pop, undef;
	$self->time_advance(2);
	ok $self->{'q'}->pop;
	$self->time_unfreeze;
}

# Popped jobs should have the same priority, tags, etc. that the
# recurring job has
sub test_recur_attributes : Tests {
	my $self = shift;
	$self->time_freeze;
	my $jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_recur_attributes'}, interval => 100, priority => -10, tags => ['foo', 'bar'], retries => 2);
	is $self->{'q'}->pop->complete, 'complete';
	for(1..10) {
		$self->time_advance(100);
		my $job = $self->{'q'}->pop;
		ok $job;
		is $job->priority, -10;
		is_deeply $job->tags, ['foo', 'bar'];
		is $job->original_retries, 2;

		ok first { $_ eq $job->jid } @{ $self->{'client'}->jobs->tagged('foo')->{'jobs'} };
		ok first { $_ eq $job->jid } @{ $self->{'client'}->jobs->tagged('bar')->{'jobs'} };
		ok !first { $_ eq $job->jid } @{ $self->{'client'}->jobs->tagged('hey')->{'jobs'} };
		
		$job->complete;
		is $self->{'q'}->pop, undef;
	}
	$self->time_unfreeze;
}

# In this test, we should get a job after offset and interval
# have passed
sub test_recur_offset : Tests {
	my $self = shift;
	$self->time_freeze;
	my $jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_recur_offset'}, interval => 100, offset => 50);

	is $self->{'q'}->pop, undef;
	$self->time_advance(30);
	is $self->{'q'}->pop, undef;
	$self->time_advance(20);
	my $job = $self->{'q'}->pop;
	ok $job;
	$job->complete;
	# And henceforth we should have jobs periodically at 100 seconds
	$self->time_advance(99);
	is $self->{'q'}->pop, undef;
	$self->time_advance(2);
	ok $self->{'q'}->pop;

	$self->time_unfreeze;
}


# In this test, we want to make sure that we can stop recurring
# jobs
# We should see these recurring jobs crop up under queues when 
# we request them
sub test_recur_off : Tests {
	my $self = shift;
	$self->time_freeze;
	my $jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_recur_off'}, interval => 100);
	is $self->{'q'}->pop->complete, 'complete';
	is $self->{'client'}->queues('testing')->counts->{'recurring'}, 1;
	is $self->{'client'}->queues->counts->[0]->{'recurring'}, 1;
	# Now, let's pop off a job, and then cancel the thing
	$self->time_advance(110);
	is $self->{'q'}->pop->complete, 'complete';
	my $job = $self->{'client'}->jobs($jid);
	is ref $job, 'Qless::RecurringJob';
	$job->cancel;
	is $self->{'client'}->queues('testing')->counts->{'recurring'}, 0;
	is $self->{'client'}->queues->counts->[0]->{'recurring'}, 0;
	$self->time_advance(1000);
	is $self->{'q'}->pop, undef;
	$self->time_unfreeze;
}



# We should be able to list the jids of all the recurring jobs
# in a queue
sub test_jobs_recur : Tests {
	my $self = shift;
	my @jids = map { $self->{'q'}->recur('Qless::Job', { 'test' => 'test_jobs_recur'}, interval => $_ * 10 ) } 1..10;
	is_deeply \@jids, $self->{'q'}->jobs->recurring;
	foreach my $jid (@jids) {
		is ref $self->{'client'}->jobs($jid), 'Qless::RecurringJob';
	}
}


# We should be able to get the data for a recurring job
sub test_recur_get : Tests {
	my $self = shift;
	$self->time_freeze;
	my $jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_recur_get'}, interval => 100, priority => -10, tags => ['foo', 'bar'], retries => 2);
	my $job = $self->{'client'}->jobs($jid);
	is ref $job, 'Qless::RecurringJob';
	is $job->priority, -10;
	is $job->queue_name, 'testing';
	is_deeply $job->data, {test => 'test_recur_get'};
	is_deeply $job->tags, ['foo', 'bar'];
	is $job->interval, 100;
	is $job->retries, 2;
	is $job->count, 0;

	# Now let's pop a job
	$self->{'q'}->pop;
	is $self->{'client'}->jobs($jid)->count, 1;
	$self->time_unfreeze;
}

sub test_passed_interval : Tests {
	my $self = shift;
	# We should get multiple jobs if we've passed the interval time
	# several times.
	$self->time_freeze;
	my $jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_passed_interval'}, interval => 100);
	is $self->{'q'}->pop->complete, 'complete';
	$self->time_advance(850);
	my @jobs = $self->{'q'}->pop(100);
	is scalar @jobs, 8;
	$_->complete foreach @jobs;

	# If we are popping fewer jobs than the number of jobs that would have
	# been scheduled, it should only make that many available
	$self->time_advance(800);
	@jobs = $self->{'q'}->pop(5);
	is scalar @jobs, 5;
	is $self->{'q'}->length, 5;
	$_->complete foreach @jobs;

	# Even if there are several recurring jobs, both of which need jobs
	# scheduled, it only pops off the needed number
	$jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_passed_interval_2'}, interval => 10);
	$self->time_advance(500);
	@jobs = $self->{'q'}->pop(5);
	is scalar @jobs, 5;
	is $self->{'q'}->length, 5;
	$_->complete foreach @jobs;

	# And if there are other jobs that are there, it should only move over
	# as many recurring jobs as needed
	$jid = $self->{'q'}->put('Qless::Job', {'foo'=>'bar'}, priority => 10);
	@jobs = $self->{'q'}->pop(5);
	is scalar @jobs, 5;
	is $self->{'q'}->length, 6;

	$self->time_unfreeze;
}

# We should see these recurring jobs crop up under queues when 
# we request them
sub test_queues_endpoint : Tests {
	my $self = shift;
	my $jid = $self->{'q'}->recur('Qless::Job', {'test'=>'test_queues_endpoint'}, interval => 100);

	is $self->{'client'}->queues('testing')->counts->{'recurring'}, 1;
	is $self->{'client'}->queues->counts->[0]->{'recurring'}, 1;
}

1;
