package Qless::ClientJobs;
=head1 NAME

Qless::ClientJobs
=cut
use strict; use warnings;
use JSON::XS qw(decode_json encode_json);
use Qless::Job;
use Qless::RecurringJob;

=head1 METHODS

=head2 C<new>
=cut
sub new {
	my $class = shift;
	my ($client) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	$self->{'client'} = $client;

	$self;
}

=head2 C<complete([$offset, $count])>

Return the paginated jids of complete jobs
=cut
sub complete {
	my ($self, $offset, $count) = @_;
	$offset ||= 0;
	$count  ||= 25;
	return $self->{'client'}->_jobs([], 'complete', $offset, $count);
}

=head2 C<tracked>

Return an array of job objects that are being tracked
=cut
sub tracked {
	my ($self) = @_;
	my $results = decode_json($self->{'client'}->_track());
	$results->{'jobs'} = [ map { Qless::Job->new($self, $_) } @{ $results->{'jobs'} } ];

	return $results;
}

=head2 C<tagged($tag[, $offset, $count])>

Return the paginated jids of jobs tagged with a tag
=cut
sub tagged {
	my ($self, $tag, $offset, $count) = @_;
	$offset ||= 0;
	$count  ||= 25;

	return decode_json($self->{'client'}->_tag([], 'get', $tag, $offset, $count));
}

=head2 C<failed([$group, $offset, $count])>

If no group is provided, this returns a JSON blob of the counts of the various types of failures known.
If a type is provided, returns paginated job objects affected by that kind of failure.
=cut
sub failed {
	my ($self, $group, $offset, $count) = @_;
	if (!$group) {
		return decode_json($self->{'client'}->_failed());
	}

	my $results =  decode_json($self->{'client'}->_failed([], $group, $offset, $count));
	$results->{'jobs'} = [ map { Qless::Job->new($self, $_) } @{ $results->{'jobs'} } ];
	return $results;
}

=head2 C<item($jid)>

Get a job object corresponding to that jid, or C<undef> if it doesn't exist
=cut
sub item {
	my ($self, $jid) = @_;

	my $results = $self->{'client'}->_get([], $jid);
	if (!$results) {
		$results = $self->{'client'}->_recur([], $jid);
		return undef if !$results;

		return Qless::RecurringJob->new($self->{'client'}, decode_json($results));
	}

	return Qless::Job->new($self->{'client'}, decode_json($results));
}


1;
