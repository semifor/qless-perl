package TestQless;
use base qw(Test::Class);
use Redis;
use Qless::Client;

sub setup : Test(setup) {
	my $self = shift;

	$self->{'redis'}  = eval { Redis->new(debug=>0) };
	if ($@) {
		$self->SKIP_ALL('No Redis server at localhost');
		return;
	}
	$self->{'redis'}->script('flush');

	$self->{'client'} = Qless::Client->new($self->{'redis'});
	$self->{'q'}      = $self->{'client'}->queues('testing');

	# worker a
	{
		my $tmp = Qless::Client->new($self->{'redis'});
		$tmp->worker_name('worker-a');
		$self->{'a'} = $tmp->queues('testing');
	}

	# worker b
	{
		my $tmp = Qless::Client->new($self->{'redis'});
		$tmp->worker_name('worker-b');
		$self->{'b'} = $tmp->queues('testing');
	}

	$self->{'other'} = $self->{'client'}->queues('other');
}

sub teardown : Test(teardown) {
	my $self = shift;

	$self->{'redis'}->flushdb();
}

1;
