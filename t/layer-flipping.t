use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


my $comic;


sub setup {
    my %layers = (
        $MockComic::DEUTSCH => [''],
        $MockComic::META_DEUTSCH => [],
        $MockComic::ENGLISH => [],
        $MockComic::META_ENGLISH => [],
        $MockComic::HINTERGRUND => [],
        $MockComic::FIGUREN => [],
    );
    foreach my $l (@_) {
        $layers{$l} = [];
    }

    $comic = MockComic::make_comic(
        $MockComic::TEXTS => \%layers, 
        $MockComic::FRAMES => [0, 0, 200, 200],
    );
}


sub setup_xml {
    my $xml = shift;
    $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => [''],
            $MockComic::ENGLISH => [''],
        },
        $MockComic::XML => $xml);
}


sub assert_visible {
    my %expected = map {$_ => 1} @_;
    my $xpath = XML::LibXML::XPathContext->new($comic->{dom});
    $xpath->registerNs($Comic::DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $allLayers = Comic::_build_xpath('g[@inkscape:groupmode="layer"]');
    foreach my $layer ($comic->{xpath}->findnodes($allLayers)) {
        my $label = $layer->{"inkscape:label"};
        my $style = $layer->{"style"};
        if (exists($expected{$label})) {
            ok($style =~ m/inline/, "$label should be visible");
        }
        else {
            ok($style =~ m/none/, "$label should not be visible");
        }
        $expected{$label} = 0;
    }
    foreach my $notseen (keys %expected) {
        ok($expected{$notseen} == 0, "Layer $notseen not in DOM");
    }
}


sub german_only : Tests {
    setup();
    $comic->_flip_language_layers("Deutsch", ("Deutsch", "English"));
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund));
}


sub englishOnly : Tests {
    setup();
    $comic->_flip_language_layers("English", ("Deutsch", "English"));
    assert_visible(qw(English Rahmen Figuren Hintergrund));
}


sub failsOnUnknownLanguage : Test {
    setup();
    eval {
        $comic->_flip_language_layers("Pimperanto", ("Deutsch", "English"));
    };
    like($@, qr/no Pimperanto layer/i);
}


sub flipsUnknownLayerWithTrailingLanguageName : Tests {
    setup('HintergrundDeutsch');
    $comic->_flip_language_layers("Deutsch", ("Deutsch", "English"));
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund HintergrundDeutsch));
}


sub ignoresUnknownLayerWithEmbeddedLanguageName : Tests {
    setup('HintergrundDeutschUndSo', 'HintergrundEnglishUndSo');
    $comic->_flip_language_layers("Deutsch", ("Deutsch", "English"));
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund 
        HintergrundDeutschUndSo HintergrundEnglishUndSo));
}


sub keeps_background_opacity : Tests {
    setup_xml('<g inkscape:groupmode="layer" id="layer18" inkscape:label="HintergrundDeutsch" style="display:inline;opacity:0.35"/>');
    $comic->_flip_language_layers("English", ("Deutsch", "English"));
    assert_visible(qw(English));

    my $xpath = XML::LibXML::XPathContext->new($comic->{dom});
    $xpath->registerNs($Comic::DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $theLayer = Comic::_build_xpath('g[@inkscape:label="HintergrundDeutsch"]');
    my $style = ($comic->{xpath}->findnodes($theLayer))[0]->{style};
    is($style, 'display:none;opacity:0.35');
}


sub no_style_on_layer : Tests {
    setup_xml('<g inkscape:groupmode="layer" id="layer18" inkscape:label="HintergrundDeutsch"/>');
    $comic->_flip_language_layers("Deutsch", ("Deutsch", "English"));
    assert_visible(qw(Deutsch HintergrundDeutsch));
}
