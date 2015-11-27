use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Comic',
    AUTHOR              => 'Robert Wenner <robert.wenner@posteo.de>',
    VERSION_FROM        => 'lib/Comic.pm',
    ABSTRACT_FROM       => 'lib/Comic.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Comic-*' },
);
