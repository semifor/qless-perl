package Qless::Worker;
=head1 NAME

Qless::Worker

=cut
use strict; use warnings;

sub new {
	my $class = shift;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self;
}


sub run {
}

sub clean {
}

1;
