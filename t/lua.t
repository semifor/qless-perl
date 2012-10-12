use strict;
use warnings;
use Test::More tests => 4;
use Redis;

use_ok('Qless::Lua');

my $redis = Redis->new();

my $script = Qless::Lua->new('config', $redis);
is $script->([], 'get', 'heartbeat'), 60;
is $script->([], 'get', 'application'), 'qless';
is $script->reload, 'a5aa719f665348051a1ebb0d099f70177abea8e4', 'SHA checksum is correct';


