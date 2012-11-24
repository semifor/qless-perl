package TestQless::Recurring;
use base qw(TestQless);
use Test::More;
use Test::Deep;

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


1;
