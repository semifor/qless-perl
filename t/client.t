use strict;
use warnings;
use Test::More qw(no_plan);
use Redis;

use_ok('Qless::Client');

my $redis = Redis->new();

my $client = Qless::Client->new($redis);

# config
my $config = $client->config;
$config->set('application', 'qless');
my $data = $config->get;
is ref $data, 'HASH',                         'All options are got as hashref';
is $data->{'application'}, 'qless',           'default "application" key is "qless"';
is $config->get('application'), 'qless',      'default "application" key is "qless", v2';
$config->set('application', 'qless-test');
is $config->get('application'), 'qless-test', 'Setting new value works';
$config->del('application');
is $config->get('application'), 'qless',      'Deleting value works, got default value';
