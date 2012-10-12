package Qless::Client;
use strict; use warnings;
use JSON::XS qw(decode_json);
use Sys::Hostname qw(hostname);
use Qless::Lua;
use Qless::Config;
use Qless::Workers;
use Qless::Queues;
use Qless::ClientJobs;

sub new {
	my $class = shift;
	my ($redis) = @_;

	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	# Redis handler
	$self->{'redis'} = $redis;

	# worker name
	$self->{'worker_name'} = hostname.'-'.$$;

	$self->{'jobs'}     = Qless::ClientJobs->new($self);
	$self->{'queues'}   = Qless::Queues->new($self);
	$self->{'workers'}  = Qless::Workers->new($self);
	$self->{'config'}   = Qless::Config->new($self);

	$self->_mk_private_lua_method($_) foreach ('cancel', 'config', 'complete', 'depends', 'fail', 'failed', 'get', 'heartbeat', 'jobs', 'peek',
            'pop', 'priority', 'put', 'queues', 'recur', 'retry', 'stats', 'tag', 'track', 'workers');

	$self;
}

sub _mk_private_lua_method {
	my ($self, $name) = @_;

	my $script = Qless::Lua->new($name, $self->{'redis'});

	no strict qw(refs);
	my $subname = __PACKAGE__.'::_'.$name;
	*{$subname} = sub {
		my $self = shift;
		$script->(@_);
	};
	use strict qw(refs);
	
}

sub track {
	my ($self, $jid) = @_;
	return $self->_track([], 'track', $jid, time);
}

sub untrack {
	my ($self, $jid) = @_;
	return $self->_track([], 'untrack', $jid, time);
}

sub tags {
	my ($self, $offset, $count) = @_;
	$offset ||= 0;
	$count  ||= 100;

	return decode_json($self->_tag([], 'top', $offset, $count));
}

# TODO
sub event { }
sub events { }

# accessors
sub config { shift->{'config'} };
sub workers { shift->{'workers'} };
sub queues { shift->{'queues'} };
sub jobs { shift->{'jobs'} };


1;
