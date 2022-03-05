use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Out::SvgPerLanguage;

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
    $comic->{'settings'}->{'LayerNames'}->{'TranscriptOnlyPrefix'} = 'Meta';
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
    foreach my $layer ($comic->{xpath}->findnodes(Comic::_all_layers_xpath())) {
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
    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "Deutsch");
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund));
}


sub english_only : Tests {
    setup();
    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "English");
    assert_visible(qw(English Rahmen Figuren Hintergrund));
}


sub fails_on_unknown_language : Tests {
    setup();
    eval {
        Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "Pimperanto");
    };
    like($@, qr/no Pimperanto layer/i);
}


sub flips_unknown_layer_with_trailing_language_name : Tests {
    setup('HintergrundDeutsch');
    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "Deutsch");
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund HintergrundDeutsch));
}


sub ignores_unknown_layer_with_embedded_language_name : Tests {
    setup('HintergrundDeutschUndSo', 'HintergrundEnglishUndSo');
    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "Deutsch");
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund
        HintergrundDeutschUndSo HintergrundEnglishUndSo));
}


sub keeps_background_opacity : Tests {
    setup_xml('<g inkscape:groupmode="layer" id="layer18" inkscape:label="HintergrundDeutsch" style="display:inline;opacity:0.35"/>');
    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "English");
    assert_visible(qw(English));

    my $xpath = XML::LibXML::XPathContext->new($comic->{dom});
    $xpath->registerNs('myNs', 'http://www.w3.org/2000/svg');
    my $theLayer = Comic::_build_xpath('g[@inkscape:label="HintergrundDeutsch"]');
    my $style = ($comic->{xpath}->findnodes($theLayer))[0]->{style};
    is($style, 'display:none;opacity:0.35');
}


sub no_style_on_layer : Tests {
    setup_xml('<g inkscape:groupmode="layer" id="layer18" inkscape:label="HintergrundDeutsch"/>');
    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "Deutsch");
    assert_visible(qw(Deutsch HintergrundDeutsch));
}


sub container_layer : Tests {
    $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="ContainerDeutsch">
        <g inkscape:groupmode="layer" id="layer20" inkscape:label="Deutsch"/>
        <g inkscape:groupmode="layer" id="layer21" inkscape:label="HintergrundDeutsch"/>
    </g>
    <g inkscape:groupmode="layer" id="layer28" inkscape:label="ContainerEnglish">
        <g inkscape:groupmode="layer" id="layer30" inkscape:label="English"/>
        <g inkscape:groupmode="layer" id="layer31" inkscape:label="HintergrundEnglish"/>
    </g>
XML
    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, "Deutsch");
    assert_visible(qw(ContainerDeutsch Deutsch HintergrundDeutsch));
}
