use strict;
use warnings;
use Test::More qw(no_plan);
use Redis;
use Data::Dumper;

use_ok('Qless::Client');


SKIP: {
	my $redis = eval { Redis->new() };
	skip 'No Redis server at localhost', 1, $@;

	my $client = Qless::Client->new($redis);

	my $q = $client->queues('testing');

	my $jid = $q->put('Test::Qless::Job', {'test' => 'put_get'});

#warn $jid;

	my $job = $client->jobs($jid);

	$job->track;


	my $qjob = $q->pop;

	warn Dumper($qjob);
	$qjob->process;
}

#$job->tag('testtag');

#warn Dumper($client->jobs->tracked);

package Test::Qless::Job;
use strict; use warnings;
use Data::Dumper;

sub process {
	my ($self, $job) = @_;
	warn "!!!!";
}
1;
