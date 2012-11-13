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

	$self->time_freeze;

	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'scheduled'}, delay => 10);

	is $self->{'q'}->pop, undef;
	is $self->{'q'}->length, 1;

	$self->time_advance(11);

	my $job = $self->{'q'}->pop;
	ok $job;
	is $job->jid, $jid;

	$self->time_unfreeze;
}


# Despite the wordy test name, we want to make sure that
# when a job is put with a delay, that its state is 
# 'scheduled', when we peek it or pop it and its state is
# now considered valid, then it should be 'waiting'
sub test_scheduled_peek_pop_state : Tests(3) {
	my $self = shift;

	$self->time_freeze;

	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'scheduled_state'}, delay => 10);
	is $self->{'client'}->jobs($jid)->state, 'scheduled';

	$self->time_advance(11);

	is $self->{'q'}->peek->state, 'waiting';
	is $self->{'client'}->jobs($jid)->state, 'waiting';

	$self->time_unfreeze;
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


# In this test, we want to verify that if we put a job
# in one queue, it's popped, and then we move it before
# it's turned in, then subsequent attempts to renew the
# lock or complete the work will fail
#   1) Put job in one queue
#   2) Pop that job
#   3) Put job in another queue
#   4) Verify that heartbeats fail
sub test_move_queue_popped : Tests(5) {
	my $self = shift;

	is $self->{'q'}->length, 0, 'Starting with empty queue';
	is $self->{'other'}->length, 0, 'Starting with empty other queue';
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'move_queue_popped'});
	is $self->{'q'}->length, 1;
	$job = $self->{'q'}->pop;
	ok $job;
	$job->move('other');
	is $job->heartbeat, 0;
}


# In this test, we want to verify that if we move a job
# from one queue to another, that it doesn't destroy any
# of the other data that was associated with it. Like 
# the priority, tags, etc.
#   1) Put a job in a queue
#   2) Get the data about that job before moving it
#   3) Move it 
#   4) Get the data about the job after
#   5) Compare 2 and 4  
sub test_move_non_destructive : Tests(8) {
	my $self = shift;
	is $self->{'q'}->length, 0, 'Starting with empty queue';
	is $self->{'other'}->length, 0, 'Starting with empty other queue';
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'move_non_destructive'}, tags => ['foo', 'bar'], priority => 5);

	my $before = $self->{'client'}->jobs($jid);
	$before->move('other');
	my $after = $self->{'client'}->jobs($jid);

	is_deeply $before->tags, ['foo', 'bar'];
	is $before->priority, 5;
	is_deeply $before->tags, $after->tags;
	is_deeply $before->data, $after->data;
	is_deeply $before->priority, $after->priority;
	is scalar @{ $after->history }, 2;
}


# In this test, we want to make sure that we can still 
# keep our lock on an object if we renew it in time.
# The gist of this test is:
#   1) A gets an item, with positive heartbeat
#   2) B tries to get an item, fails
#   3) A renews its heartbeat successfully
sub test_heartbeat : Tests(7) {
	my $self = shift;
	is $self->{'a'}->length, 0, 'Starting with empty queue';
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'heartbeat'});
	my $ajob = $self->{'a'}->pop;
	ok $ajob;
	my $bjob = $self->{'a'}->pop;
	ok !$bjob;
	ok $ajob->heartbeat =~ /^\d+(\.\d+)?$/;
	ok $ajob->ttl > 0;
	$self->{'q'}->heartbeat(-60);
	ok $ajob->heartbeat =~ /^\d+(\.\d+)?$/;
	ok $ajob->ttl <= 0;
}


# In this test, we want to make sure that when we heartbeat a 
# job, its expiration in the queue is also updated. So, supposing
# that I heartbeat a job 5 times, then its expiration as far as
# the lock itself is concerned is also updated
sub test_heartbeat_expiration : Tests(21) {
	my $self = shift;

	$self->{'client'}->config->set('crawl-heartbeat', 7200);
	my $jid = $self->{'q'}->put('Qless::Job', {});

	my $job = $self->{'a'}->pop;
	ok !$self->{'b'}->pop;
	$self->time_freeze;
	for (1..10) {
		$self->time_advance(3600);
		ok $job->heartbeat;
		ok !$self->{'b'}->pop;
	}
	$self->time_unfreeze;
}


# In this test, we want to make sure that we cannot heartbeat
# a job that has not yet been popped
#   1) Put a job
#   2) DO NOT pop that job
#   3) Ensure we cannot heartbeat that job
sub test_heartbeat_state : Tests(2) {
	my $self = shift;
	is $self->{'q'}->length, 0, 'Starting with empty queue';
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'heartbeat_state'});
	my $job = $self->{'client'}->jobs($jid);
	ok !$job->heartbeat;
}


# Make sure that we can safely pop from an empty queue
#   1) Make sure the queue is empty
#   2) When we pop from it, we don't get anything back
#   3) When we peek, we don't get anything
sub test_peek_pop_empty : Tests(3) {
	my $self = shift;
	is $self->{'q'}->length, 0, 'Starting with empty queue';
	ok !$self->{'q'}->pop;
	ok !$self->{'q'}->peek;
}


# In this test, we want to put a job and peek that job, we 
# get all the attributes back that we expect
#   1) put a job
#   2) peek said job, check existence of attributes
sub test_peek_attributes : Tests(11) {
	my $self = shift;

	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'peek_attributes'});
	my $job = $self->{'q'}->peek;

	is_deeply $job->data, {'test'=>'peek_attributes'};
	is $job->worker_name, '';
	is $job->state, 'waiting';
	is $job->queue_name, 'testing';
	is $job->queue->name, 'testing';
	is $job->retries_left, 5;
	is $job->original_retries, 5;
	is $job->jid, $jid;
	is $job->klass, 'Qless::Job';
	is_deeply $job->tags, [];

	$jid = $self->{'q'}->put('Foo::Job', {'test'=>'peek_attributes'});
	$job = $self->{'q'}->pop;
	$job = $self->{'q'}->peek;
	is $job->klass, 'Foo::Job';
}


# In this test, we're going to have two queues that point
# to the same queue, but we're going to have them represent
# different workers. The gist of it is this
#   1) A gets an item, with negative heartbeat
#   2) B gets the same item,
#   3) A tries to renew lock on item, should fail
#   4) B tries to renew lock on item, should succeed
#   5) Both clean up
sub test_locks : Tests(6) {
	my $self = shift;
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'locks'});
	# Reset our heartbeat for both A and B
	$self->{'client'}->config->set('heartbeat', -10);

	# Make sure a gets a job
	my $ajob = $self->{'a'}->pop;
	ok $ajob;

	# Now, make sure that b gets that same job
	my $bjob = $self->{'b'}->pop;
	ok $bjob;
	is $ajob->jid, $bjob->jid;
	ok $bjob->heartbeat =~ /^\d+(\.\d+)?$/;
	ok $bjob->heartbeat + 11 >= time;
	ok !$ajob->heartbeat;
}


# When a worker loses a lock on a job, that job should be removed
# from the list of jobs owned by that worker
sub test_locks_workers : Tests(5) {
	my $self = shift;
	my $jid = $self->{'q'}->put('Qless::Job', {'test'=>'locks'}, retries => 1);
	$self->{'client'}->config->set('heartbeat', -10);
	my $ajob = $self->{'a'}->pop;

	# Get the workers
	my $workers = +{ map { $_->{'name'} => $_ } @{ $self->{'client'}->workers->counts } };
	is $workers->{ $self->{'a'}->worker_name }->{'stalled'}, 1;

	# Should have one more retry, so we should be good
	my $bjob = $self->{'b'}->pop;
	$workers = +{ map { $_->{'name'} => $_ } @{ $self->{'client'}->workers->counts } };
	is $workers->{ $self->{'a'}->worker_name }->{'stalled'}, 0;
	is $workers->{ $self->{'b'}->worker_name }->{'stalled'}, 1;

	# Now it's automatically failed. Shouldn't appear in either worker
	$bjob = $self->{'b'}->pop;
	$workers = +{ map { $_->{'name'} => $_ } @{ $self->{'client'}->workers->counts } };
	is $workers->{ $self->{'a'}->worker_name }->{'stalled'}, 0;
	is $workers->{ $self->{'b'}->worker_name }->{'stalled'}, 0;
}


1;
