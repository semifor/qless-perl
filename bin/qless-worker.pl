#!/usr/bin/env perl
use strict; use warnings;
use Getopt::Long;
use Redis;
use lib '/home/nuclon/workspace/qless-perl/lib';
use Qless::Worker;
use Data::Dumper;
use Class::Load qw(load_class);

my $opt = {};
GetOptions($opt,
	'host=s',
	'socket=s',
	'queue|q=s@',
	'include|I=s@',
	'interval|i=i',
	'workers|w=i',
	'name|n=s',
	'import|m=s@',
	'resume|r',
	'debug',
	'help|h',
);

my $DEBUG = $opt->{'debug'};

# Queues to poll
$opt->{'queue'} = [ split(/,/, join(',', @{ $opt->{'queue'} })) ] if $opt->{'queue'};
if ($opt->{'help'} || !$opt->{'queue'}) {
	usage();
	exit(1);
}

# include paths
unshift @INC, @{ $opt->{'include'} } if $opt->{'include'};


my $worker = Qless::Worker->new(%{ $opt });

# Preload modules
if ($opt->{'import'}) {
	foreach my $class (@{ $opt->{'import'} }) {
		load_class $class;
	}
}

warn Dumper($worker);

$worker->run;


sub usage {
	print <<EOB;
usage: $0 [options]
options:
  --host server:port
  --socket unix_socket_path
     The host:port or unix_socket to connect to as the Redis server

  -q queue_name
  --queue queue_name
     The queues to pull work from

  -I path
  --include path
      Path(s) to include when loading jobs

  -w count
  --workers count
      How many processes to run.

  -i seconds
  --interval seconds
      The polling interval

  -n worker_name
  --name worker_name
      Name to identify your worker as

  -r
  --resume
      Try to resume jobs when the worker agent is restarted

  -m module_name
  --import
      The modules to preemptively import

  --debug
      Print messages to STDOUT and do not detouch from console

  -h
  --help
      Print this message
EOB
}
