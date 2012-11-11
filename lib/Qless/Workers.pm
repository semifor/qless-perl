package Qless::Workers;
=head1 NAME

Qless::Workers
=cut
use strict; use warnings;
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
	return decode_json($self->{'client'}->_workers([], time));
}

sub item {
	my ($self, $name) = @_;
	my $rv = decode_json($self->{'client'}->_workers([], time, $name));
	$rv->{'jobs'}    ||= [];
	$rv->{'stalled'} ||= [];

	$rv;
}


1;
