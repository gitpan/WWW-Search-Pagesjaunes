use ExtUtils::MakeMaker;
WriteMakefile(
	NAME          => 'WWW::Search::Pagesjaunes',
	VERSION_FROM  => 'lib/WWW/Search/Pagesjaunes.pm',
	PREREQ_PM     => {
		'HTML::Form'       => 0,
		'LWP::UserAgent'   => 1.80,
		'HTML::TokeParser' => 0,
		'Pod::Usage'       => 0,
	},
	EXE_FILES     => [ 'pagesjaunes' ],
	ABSTRACT_FROM => 'lib/WWW/Search/Pagesjaunes.pm',
	AUTHOR        => 'Briac Pilpré <briac@cpan.org>',
);
