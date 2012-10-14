package Qless::Queue;
use strict; use warnings;
use JSON::XS qw(decode_json encode_json);
use Qless::Jobs;
use Qless::Job;

sub new {
	my $class = shift;
	my ($name, $client, $worker_name) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{'name'}        = $name;
	$self->{'client'}      = $client;
	$self->{'worker_name'} = $worker_name;

	$self;
}

sub generate_jid {
	my ($self, $data) = @_;
	return $self->{'worker_name'}.'-'.time.'-'.sprintf('%06d', int(rand(999999)));
}

sub jobs {
	my ($self) = @_;
	Qless::Jobs->new($self->{'name'}, $self->{'client'});
}

sub counts {
	my ($self) = @_;
	return decode_json($self->{'client'}->_queues([], time, $self->{'name'}));
}

sub heartbeat {
	my ($self, $new_value) = @_;

	my $config = $self->{'client'}->config;

	if (defined $new_value) {
		$config->set($self->{'name'}.'-heartbeat', $new_value);
		return;
	}

	return $config->get($self->{'name'}.'-heartbeat') || $config->get('heartbeat') || 60;
}

sub put {
	my ($self, $klass, $data, %args ) = @_;

	return $self->{'client'}->_put([$self->{'name'}],
		$args{'jid'} || $self->generate_jid($data),
		$klass,
		encode_json($data),
		time,
		$args{'delay'} || 0,
		'priority', $args{'priority'} || 0,
		'tags', encode_json($args{'tags'} || []),
		'retries', $args{'retries'} || 5,
		'depends', encode_json($args{'depends'} || []),
	);
}

sub recur {
	my ($self, $klass, $data, $interval, %args) = @_;

	return $self->{'client'}->_recur([], 'on', $self->{'name'},
		$args{'jid'} || $self->generate_jid($data),
		$klass,
		encode_json($data),
		time,
		'interval', $interval, $args{'offset'} || 0,
		'priority', $args{'priority'} || 0,
		'tags', encode_json($args{'tags'} || []),
		'retries', $args{'retries'} || 5,
	);

}

sub pop {
	my ($self, $count) = @_;
	my $jobs = [ map { Qless::Job->new($self->{'client'}, decode_json($_)) }
		@{ $self->{'client'}->_pop([$self->{'name'}], $self->{'worker_name'}, $count||1, time) } ];
	if (!defined $count) {
		return scalar @{ $jobs } ?  $jobs->[0] : undef;
	}

	return $jobs;
}

sub peek {
	my ($self, $count) = @_;
	my $jobs = [ map { Qless::Job->new($self->{'client'}, decode_json($_)) }
		@{ $self->{'client'}->_peek([$self->{'name'}], $count||1, time) } ];
	if (!defined $count) {
		return scalar @{ $jobs } ?  $jobs->[0] : undef;
	}

	return $jobs;
}

sub stats {
	my ($self, $date) = @_;
	return decode_json($self->{'client'}->_stats([], $self->{'name'}, $date || time));
}

sub length {
	my ($self) = @_;

	my $redis = $self->{'client'}->{'redis'};
	my $sum = 0;
	my $sum_cb = sub { $sum += shift };

	$redis->zcard('ql:q:'.$self->{'name'}.'-locks',     $sum_cb);
	$redis->zcard('ql:q:'.$self->{'name'}.'-work',      $sum_cb);
	$redis->zcard('ql:q:'.$self->{'name'}.'-scheduled', $sum_cb);
	$redis->wait_all_responses;

	return $sum;
}

1;
