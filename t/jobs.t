use strict;
use warnings;
use Test::More qw(no_plan);
use Redis;
use Data::Dumper;

use_ok('Qless::Client');

my $redis = Redis->new();

my $client = Qless::Client->new($redis);

my $q = $client->queues->item('testing');

my $jid = $q->put('Qless::Job', {'test' => 'put_get'});

my $job = $client->jobs->item($jid);
