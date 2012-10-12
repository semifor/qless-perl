package Qless::Job;
use strict; use warnings;
use base 'Qless::BaseJob';
use Data::Dumper;
use JSON::XS qw(decode_json encode_json);

sub new {
	my $class = shift;

	my ($client, $args) = @_;

	$class = ref $class if ref $class;
	my $self = $class->SUPER::new($client, $args);

	foreach my $key (qw(state tracked failure history dependents dependencies)) {
		$self->{$key} = $args->{ $key };
	}
	$self->{'dependents'} ||= [];
	$self->{'dependencies'} ||= [];

	$self->{'expires_at'}       = $args->{'expires'};
	$self->{'original_retries'} = $args->{'retries'};
	$self->{'retries_left'}     = $args->{'remaining'};
	$self->{'worker_name'}      = $args->{'worker'};

	$self;
}

sub ttl {
	my ($self) = @_;
	return $self->{'expires_at'} - time;
}

sub process {
	my ($self) = @_;
}

sub move {
	my ($self, $queue, $delay, $depends) = @_;

	return $self->{'client'}->_put([$queue],
		$self->{'jid'},
		$self->{'klass_name'},
		encode_json($self->{'data'}),
		time,
		$delay||0,
		'depends', encode_json($depends||[])
	);
}

sub complete {
	my ($self, $next, $delay, $depends) = @_;
	
	if ($next) {
		return $self->{'client'}->_complete([], $self->{'jid'}, $self->{'client'}->{'worker_name'}, $self->{'queue_name'},
			time, encode_json($self->{'data'}), 'next', $next, 'delay', $delay||0, 'depends', encode_json($depends||[])
		);
	}
	else {
		return $self->{'client'}->_complete([], $self->{'jid'}, $self->{'client'}->{'worker_name'}, $self->{'queue_name'},
			time, encode_json($self->{'data'})
		);
	}
}

sub heartbeat {
	my ($self) = @_;

	return $self->{'expires_at'} = $self->{'client'}->_heartbeat([],
		$self->{'jid'}, $self->{'client'}->{'worker_name'}, time, encode_json($self->{'data'})
	) || 0;
}


sub fail {
	my ($self, $group, $message) = @_;

	return $self->{'client'}->_fail([], $self->{'jid'}, $self->{'client'}->{'worker_name'}, $group, $message, time, encode_json($self->{'data'}));
}

sub track {
	my ($self) = @_;

	return $self->{'client'}->_track([], 'track', $self->{'jid'}, time);
}

sub untrack {
	my ($self) = @_;

	return $self->{'client'}->_track([], 'untrack', $self->{'jid'}, time);
}

sub retry {
	my ($self, $delay) = @_;

	return $self->{'client'}->_retry([], $self->{'jid'}, $self->{'queue_name'}, $self->{'worker_name'}, time, $delay||0);
}

sub depend {
	my ($self, @args) = @_;
	return $self->{'client'}->_depends([], $self->{'jid'}, 'on', @args);
}

sub undepend {
	my ($self, @args) = @_;
	if ($args[0] eq 'all') {
		return $self->{'client'}->_depends([], $self->{'jid'}, 'off', 'all');
	}
	return $self->{'client'}->_depends([], $self->{'jid'}, 'off', @args);
}

1;
