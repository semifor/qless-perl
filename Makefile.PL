use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;


install_share dist => 'share';

WriteMakefile(
	NAME                => 'Qless',
	ABSTRACT            => 'Perl binding for qless job queue system',
	AUTHOR              => q{Anatoliy Lapitskiy <nuclon@cpan.org>},
	VERSION_FROM        => 'lib/Qless.pm',
	ABSTRACT_FROM       => 'lib/Qless.pm',

	BUILD_REQUIRES => {
		'Test::More' => 0,
	},
	CONFIGURE_REQUIRES  => {
		'File::ShareDir::Install' => 0,
	},

	($ExtUtils::MakeMaker::VERSION >= 6.3002
	  ? ('LICENSE'=> 'perl')
	  : ()),
	PL_FILES            => {},
	PREREQ_PM => {
		'Redis' => 0,
		'JSON::XS' => 0,
		'File::ShareDir' => 0,
	},
	dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean               => { FILES => 'Qless-*' },
);

{
	package MY;
	use File::ShareDir::Install qw(postamble);
}
