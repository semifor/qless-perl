use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker 6.31;

use File::ShareDir::Install;
install_share dist => 'share';

my %WriteMakefileArgs = (
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
		'Class::Load' => 0,
		'File::ShareDir::Install' => 0,
	},
	dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean               => { FILES => 'Qless-*' },
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);


{
	package MY;
	use File::ShareDir::Install qw(postamble);
}
