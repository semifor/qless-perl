package Qless::Jobs;
use strict; use warnings;
sub new {
	my $class = shift;
	my ($client) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{'client'} = $client;

	$self;
}


1;
