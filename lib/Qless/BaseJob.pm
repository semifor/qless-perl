package Qless::BaseJob;
use strict; use warnings;

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

	$self->{'klass'}      = $args->{'klass'};
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
	return $self->{'queue'} = $self->{'client'}->queues($self->{'queue_name'});
}

sub client { $_[0]->{'client'} }
sub queue_name { $_[0]->{'queue_name'} }
sub klass { $_[0]->{'klass'} }
sub data { $_[0]->{'data'} }
sub jid { $_[0]->{'jid'} }
sub tags { $_[0]->{'tags'} }

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

