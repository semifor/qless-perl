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

1;
