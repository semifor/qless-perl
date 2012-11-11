package Qless::Queues;
=head1 NAME

Qless::Queues
=cut
use strict; use warnings;
use Qless::Queue;
use JSON::XS qw(decode_json);
use Time::HiRes qw(time);

sub new {
	my $class = shift;
	my ($client) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{'client'} = $client;

	$self;
}

sub counts {
	my ($self) = @_;
	return decode_json($self->{'client'}->_queues([], time));
}

sub item {
	my ($self, $name) = @_;
	return Qless::Queue->new($name, $self->{'client'}, $self->{'client'}->{'worker_name'});
}

1;
