use strict;
use warnings;
use ExtUtils::MakeMaker;

my %dependencies = (
    'Authen::SASL' => 0,
    'autodie' => 0,
    'autovivification' => 0,
    'Clone' => 0,
    'DateTime' => 0,
    'DateTime::Format::ISO8601' => 0,
    'DateTime::Format::RFC3339' => 0,
    'Email::MIME' => 0,
    'Email::MessageID' => 0,
    'Email::Sender::Simple' => 0,
    'Email::Sender::Transport::SMTP' => 0,
    'ExtUtils::MakeMaker' => 0,
    'File::Rsync' => 0,
    'File::Slurper' => 0,
    'File::Util' => 0,
    'Hash::Merge' => 0,
    'HTML::Entities' => 0,
    'HTTP::Tiny' => 0,
    'Image::ExifTool' => 0,
    'Imager::QRCode' => 0,
    'Image::SVG::Transform' => 0,
    'JSON' => 0,
    'Locales' => 0,
    'Net::Twitter' => 0,
    'Net::IDN::Encode' => 0,
    'MIME::Base64' => 0,
    'Readonly' => 0,
    'Reddit::Client' => 0,
    'String::Util' => 0,
    'SVG' => 0,
    'Template' => 0,
    'Template::Plugin::JSON' => 0,
    'Text::Aspell' => 0,
    'Text::SpellChecker' => 0,
    'URI::Escape' => 0,
    'XML::LibXML' => 0,
    'XML::LibXML::XPathContext' => 0,
    'version' => 0,
);

my %test_dependencies = (
    'Capture::Tiny' => 0,
    'Test::More' => 0,
    'Test::Class' => 0,
    'Test::Distribution' => 0,
    'Test::MockModule' => 0,
    'Test::NoWarnings' => 0,
    'Test::Output' => 0,
);

WriteMakefile(
    NAME => 'Comic',
    AUTHOR => 'Robert Wenner <rwenner@cpan.org>',
    VERSION_FROM => 'lib/Comic.pm',
    ABSTRACT_FROM => 'lib/Comic.pm',
    PL_FILES => {},
    PREREQ_PM => {
        %dependencies,
        %test_dependencies,
    },
    MIN_PERL_VERSION => 5.22.0,
    LICENSE => 'perl_5',
    META_ADD => {
        "meta-spec" => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url => 'git://github.com/robertwenner/comics',
                web => 'https://github.com/robertwenner/comics',
            },
        },
        provides => {
            'Comic' => {
                file => 'lib/Comic.pm',
                version => '0.0.3',
            },
        },
    },
    dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Comic-*' },
    BUILD_REQUIRES => { %dependencies },
    test => { RECURSIVE_TEST_FILES => 1, },
);


sub MY::postamble {
    return <<HERE;
cover :: pure_all
	HARNESS_PERL_SWITCHES=-MDevel::Cover make test && cover -report html_basic

atest :: pure_all
	TEST_AUTHOR=1 prove t/author/*.t
HERE
}
