package TestQless::General;
use base qw(TestQless);
use Test::More;
use Data::Dumper;

sub test_config : Tests(5) {
	my $self = shift;

	# Set this particular configuration value
	my $config = $self->{'client'}->config;
	$config->set('testing', 'foo');
	is $config->get('testing'), 'foo';

	# Now let's get all the configuration options and make
	# sure that it's a HASHREF, and that it has a key for 'testing'
	is ref $config->get, 'HASH';
	is $config->get->{'testing'}, 'foo';

	# Now we'll delete this configuration option and make sure that
	# when we try to get it again, it doesn't exist
	$config->del('testing');
	is $config->get('testing'), undef;
	ok(!exists $config->get->{'testing'});
}


# In this test, I want to make sure that I can put a job into
# a queue, and then retrieve its data
#   1) put in a job
#   2) get job
#   3) delete job
sub test_put_get : Tests(7) {
	my $self = shift;

	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'put_get'});
	my $put_time = time;
	my $job = $self->{'client'}->jobs($jid);

	is $job->priority, 0;
	is_deeply $job->data, {'test' => 'put_get' };
	is_deeply $job->tags, [];
	is $job->worker_name, '';
	is $job->state, 'waiting';
	is $job->klass, 'Qless::Job';
	is_deeply $job->history, [{
			'q' => 'testing',
			'put' => $put_time,
		}];
}


# In this test, I want to make sure that I can put a job into
# a queue, and then retrieve its data
#   1) put in a job
#   2) get job
#   3) delete job
sub test_push_peek_pop_many : Tests(6) {
	my $self = shift;

	is $self->{'q'}->length, 0, 'Starting with empty queue';

	my @jids = map { $self->{'q'}->put('Qless::Job', { 'test' => 'push_pop_many', count => $_ }) } 1..10;
	is $self->{'q'}->length, scalar @jids, 'Inserting should increase the size of the queue';

	# Alright, they're in the queue. Let's take a peek
	is scalar @{ $self->{'q'}->peek(7) }, 7;
	is scalar @{ $self->{'q'}->peek(10) }, 10;

	# Now let's pop them all off one by one
	is scalar @{ $self->{'q'}->pop(7) }, 7;
	is scalar @{ $self->{'q'}->pop(10) }, 3;
}


# In this test, we want to put a job, pop a job, and make
# sure that when popped, we get all the attributes back 
# that we expect
#   1) put a job
#   2) pop said job, check existence of attributes
sub test_put_pop_attributes : Tests(12) {
	my $self = shift;

	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'test_put_pop_attributes'});
	$self->{'client'}->config->set('heartbeat', 60);

	my $job = $self->{'q'}->pop;

	is_deeply $job->data, {'test'=>'test_put_pop_attributes'};
	is $job->worker_name, $self->{'client'}->worker_name;
	ok $job->ttl > 0;
	is $job->state, 'running';
	is $job->queue_name, 'testing';
	is $job->queue->name, 'testing';
	is $job->retries_left, 5;
	is $job->original_retries, 5;
	is $job->jid, $jid;
	is $job->klass, 'Qless::Job';
	is_deeply $job->tags, [];

	$jid = $self->{'q'}->put('Foo::Job', {'test'=>'test_put_pop_attributes'});
	$job = $self->{'q'}->pop;
	is $job->klass, 'Foo::Job';
}

# In this test, we're going to add several jobs and make
# sure that we get them in an order based on priority
#   1) Insert 10 jobs into the queue with successively more priority
#   2) Pop all the jobs, and ensure that with each pop we get the right one
sub test_put_pop_priority : Tests(11) {
	my $self = shift;
	is $self->{'q'}->length, 0, 'Starting with empty queue';
	my @jids = map { $self->{'q'}->put('Qless::Job', { 'test' => 'put_pop_priority', count => $_ }, priority => $_) }  0..9;
	my $last = scalar @jids;
	foreach (@jids) {
		my $job = $self->{'q'}->pop;
		ok $job->data->{'count'} < $last, 'We should see jobs in reverse order';
		$last = $job->data->{'count'};
	}
}


# In this test, we want to make sure that jobs are popped
# off in the same order they were put on, priorities being
# equal.
#   1) Put some jobs
#   2) Pop some jobs, save jids
#   3) Put more jobs
#   4) Pop until empty, saving jids
#   5) Ensure popped jobs are in the same order
sub test_same_priority_order : Tests(1) {
	my $self = shift;
	my $jids   = [];
	my $popped = [];
	for(0..99) {
		push @{ $jids }, $self->{'q'}->put('Qless::Job', { 'test' => 'put_pop_order', 'count' => 2*$_ });
		$self->{'q'}->peek;
		push @{ $jids }, $self->{'q'}->put('Foo::Job', { 'test' => 'put_pop_order', 'count' => 2*$_+1 });
		push @{ $popped }, $self->{'q'}->pop->jid;
		$self->{'q'}->peek;
	}

	
	push @{ $popped }, map { $self->{'q'}->pop->jid } 0..99;

	is_deeply $jids, $popped;
}


# In this test, we'd like to make sure that we can't pop
# off a job scheduled for in the future until it has been
# considered valid
#   1) Put a job scheduled for 10s from now
#   2) Ensure an empty pop
#   3) 'Wait' 10s
#   4) Ensure pop contains that job
# This is /ugly/, but we're going to path the time function so
# that we can fake out how long these things are waiting
sub test_scheduled : Tests(5) {
	my $self = shift;

	is $self->{'q'}->length, 0, 'Starting with empty queue';
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'scheduled'}, delay => 10);

	is $self->{'q'}->pop, undef;
	is $self->{'q'}->length, 1;

	sleep(11);

	my $job = $self->{'q'}->pop;
	ok $job;
	is $job->jid, $jid;

}

# Despite the wordy test name, we want to make sure that
# when a job is put with a delay, that its state is 
# 'scheduled', when we peek it or pop it and its state is
# now considered valid, then it should be 'waiting'
sub test_scheduled_peek_pop_state : Tests(3) {
	my $self = shift;
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'scheduled_state'}, delay => 10);
	is $self->{'client'}->jobs($jid)->state, 'scheduled';

	sleep(11);

	is $self->{'q'}->peek->state, 'waiting';
	is $self->{'client'}->jobs($jid)->state, 'waiting';
}

# In this test, we want to put a job, pop it, and then 
# verify that its history has been updated accordingly.
#   1) Put a job on the queue
#   2) Get job, check history
#   3) Pop job, check history
#   4) Complete job, check history
sub test_put_pop_complete_history : Tests(3) {
	my $self = shift;
	is $self->{'q'}->length, 0, 'Starting with empty queue';

	my $put_time = time;
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'put_history'});
	my $job = $self->{'client'}->jobs($jid);
	is $job->history->[0]->{'put'}, $put_time;

	my $pop_time = time;
	$job = $self->{'q'}->pop;
	$job = $self->{'client'}->jobs($jid);
	is $job->history->[0]->{'popped'}, $pop_time;
}

# In this test, we want to verify that if we put a job
# in one queue, and then move it, that it is in fact
# no longer in the first queue.
#   1) Put a job in one queue
#   2) Put the same job in another queue
#   3) Make sure that it's no longer in the first queue
sub test_move_queue : Tests(5) {
	my $self = shift;

	is $self->{'q'}->length, 0, 'Starting with empty queue';
	is $self->{'other'}->length, 0, 'Starting with empty other queue';
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'move_queue'});
	is $self->{'q'}->length, 1;
	my $job = $self->{'client'}->jobs($jid);
	$job->move('other');
	is $self->{'q'}->length, 0;
	is $self->{'other'}->length, 1;
}

1;
