use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

use Comic::Out::SvgPerLanguage;


__PACKAGE__->runtests() unless caller;


my $spl;
my $wrote_to;


sub set_up : Test(setup) {
    MockComic::set_up();

    no warnings qw/redefine/;
    *Comic::Out::SvgPerLanguage::_write = sub {
        my ($self, $file) = @_;
        $wrote_to = $file;
        return;
    };
    use warnings;

    $spl = Comic::Out::SvgPerLanguage->new({
        'Comic::Out::SvgPerLanguage' => {
            'outdir' => 'generated',
        },
    });
}


sub ctor_complains_if_no_config : Tests {
    eval {
        Comic::Out::SvgPerLanguage->new();
    };
    like($@, qr{no Comic::Out::SvgPerLanguage configuration}i);
}


sub ctor_uses_default_outdir : Tests {
    $spl = Comic::Out::SvgPerLanguage->new({
        'Comic::Out::SvgPerLanguage' => {
        },
    });
    like($spl->{settings}->{outdir}, qr{^[\w/]+}, 'should have something that looks like a path');
}


sub ctor_adds_trailing_slash_to_outdir : Tests {
    $spl = Comic::Out::SvgPerLanguage->new({
        'Comic::Out::SvgPerLanguage' => {
            'outdir' => 'generated/',
        },
    });
    is($spl->{settings}->{outdir}, 'generated/');
    $spl = Comic::Out::SvgPerLanguage->new({
        'Comic::Out::SvgPerLanguage' => {
            'outdir' => 'generated',
        },
    });
    is($spl->{settings}->{outdir}, 'generated/');
}


sub generate_ok : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::TEXTS => {
            $MockComic::ENGLISH => ['burp'],
        },
    );
    $spl->generate($comic);
    is($wrote_to, 'generated/English/latest-comic.svg', 'wrote wrong svg file');
    is($comic->{svgFile}{'English'}, 'generated/English/latest-comic.svg', 'saved wrong file name in Comic');
}


sub generate_does_nothing_if_svg_is_cached: Tests {
    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        my ($source, $target) = @_;
        return $target =~ m/\.svg$/;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::TEXTS => {
            $MockComic::ENGLISH => ['burp'],
        },
    );
    $spl->generate($comic);
    is($wrote_to, undef, 'should not write a svg file');
    is($comic->{svgFile}{'English'}, 'generated/English/latest-comic.svg', 'saved wrong file name in Comic');
}


sub fails_if_language_layer_not_found : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    eval {
        $spl->generate($comic);
    };
    like($@, qr{\blayer\b}, 'should say what is missing');
    like($@, qr{\bEnglish\b}, 'should mention language');
}
