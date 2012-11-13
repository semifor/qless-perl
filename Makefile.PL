use inc::Module::Install;
use Module::Install::Share;

name 'Qless';
author 'Anatoliy Lapitskiy <nuclon@cpan.org>';
license 'artistic2';
perl_version '5.006';
version_from 'lib/Qless.pm';

test_requires 'Test::More';
test_requires 'Test::Class';

requires 'Redis';
requires 'JSON::XS';
requires 'File::ShareDir';
requires 'Class::Load';
requires 'Time::HiRes';

install_share;

WriteAll;
