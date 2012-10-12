package Qless::BaseJob;
use strict; use warnings;
use Data::Dumper;

sub new {
	my $class = shift;

	my ($client, $args) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{'client'} = $client;

	$self->{'_loaded'} = {};
	foreach my $key (qw(data jid priority)) {
		$self->{$key} = $args->{ $key };
	}

	$self->{'klass_name'} = $args->{'klass'};
	$self->{'queue_name'} = $args->{'queue'};
	$self->{'tags'}       = $args->{'tags'} || [];

	$self;
}

sub priority {
	my ($self, $value) = @_;
	$self->{'client'}->_priority([], $self->{'jid'}, $value);
	$self->{'priority'} = $value;
}

sub queue {
	my ($self) = @_;

	return $self->{'queue'} = $self->{'client'}->queues->item($self->{'queue_name'});
}

sub klass {
	my ($self) = @_;
	return $self->{'klass_name'};
}

sub cancel {
	my ($self) = @_;
	$self->{'client'}->_cancel([], $self->{'jid'});
}

sub tag {
	my ($self, @tags) = @_;
	$self->{'client'}->_tag([], 'add', $self->{'jid'}, time, @tags);
}

sub untag {
	my ($self, @tags) = @_;
	$self->{'client'}->_tag([], 'remove', $self->{'jid'}, time, @tags);
}

1;

