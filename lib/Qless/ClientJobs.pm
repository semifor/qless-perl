package Qless::ClientJobs;
use strict; use warnings;
use Qless::Job;

sub new {
	my $class = shift;
	my ($client) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{'client'} = $client;

	$self;
}

sub complete {
	my ($self, $offset, $count) = @_;
	$offset ||= 0;
	$count  ||= 25;
	return $self->{'client'}->_jobs([], 'complete', $offset, $count);
}

sub tracked {
	my ($self) = @_;
	my $results = decode_json($self->{'client'}->_track());
	$results->{'jobs'} = [ map { Qless::Job->new($self, %{ $_ }) } @{ $results->{'jobs'} } ];

	return $results;
}

sub tagged {
	my ($self, $tag, $offset, $count) = @_;
	$offset ||= 0;
	$count  ||= 25;

	return decode_json($self->{'client'}->_tag([], 'get', $tag, $offset, $count));
}

sub failed {
	my ($self, $group, $offset, $count) = @_;
	if (!$group) {
		return decode_json($self->{'client'}->_failed());
	}

	my $results =  decode_json($self->{'client'}->_failed([], $group, $offset, $count));
	$results->{'jobs'} = [ map { Qless::Job->new($self, %{ $_ }) } @{ $results->{'jobs'} } ];
	return $results;
}

sub by_jid {
	my ($self, $jid) = @_;

	my $results = $self->{'client'}->_get([], $jid);
	if (!$results) {
		$results = $self->{'client'}->_recur([], $jid);
		return undef if !$results;

		return Qless::RecurringJob($self->{'client'}, %{ decode_json($results) });
	}

	return Qless::Job($self->{'client'}, %{ decode_json($results) });
}


1;
