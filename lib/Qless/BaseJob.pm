package Qless::BaseJob;
use strict; use warnings;

sub new {
	my $class = shift;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self;
}

1;

