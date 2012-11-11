use inc::Module::Install;
use Module::Install::Share;

name 'Qless';
all_from 'lib/Qless.pm';

test_requires 'Test::More';
test_requires 'Test::Class';

requires 'Redis';
requires 'JSON::XS';
requires 'File::ShareDir';
requires 'Class::Load';
requires 'Time::HiRes';

install_share;

WriteAll;
