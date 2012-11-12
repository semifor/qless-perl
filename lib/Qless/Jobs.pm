package Qless::Jobs;
=head1 NAME

Qless::Jobs

=cut

use strict; use warnings;
use Time::HiRes qw(time);
sub new {
	my $class = shift;
	my ($name, $client) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{'name'}   = $name;
	$self->{'client'} = $client;

	$self;
}

sub running {
	my ($self, $offset, $count) = @_;
	return $self->{'client'}->_jobs([], 'running', time, $self->{'name'}, $offset||0, $count||25);
}

sub stalled {
	my ($self, $offset, $count) = @_;
	return $self->{'client'}->_jobs([], 'stalled', time, $self->{'name'}, $offset||0, $count||25);
}

sub scheduled {
	my ($self, $offset, $count) = @_;
	return $self->{'client'}->_jobs([], 'scheduled', time, $self->{'name'}, $offset||0, $count||25);
}

sub depends {
	my ($self, $offset, $count) = @_;
	return $self->{'client'}->_jobs([], 'depends', time, $self->{'name'}, $offset||0, $count||25);
}

sub recurring {
	my ($self, $offset, $count) = @_;
	return $self->{'client'}->_jobs([], 'recurring', time, $self->{'name'}, $offset||0, $count||25);
}

1;
