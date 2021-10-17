use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

use Comic::Out::Copyright;


__PACKAGE__->runtests() unless caller;


my $copyright;


sub set_up : Test(setup) {
    MockComic::set_up();
    $copyright = Comic::Out::Copyright->new(
        'text' =>  {
            'English' => 'beercomics.com',
            'Deutsch' => 'biercomics.de',
        },
    );
}


sub make_comic {
    my %layers = (
        $MockComic::DEUTSCH => ['blah'],
    );
    foreach my $l (@_) {
        $layers{$l} = [];
    }

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'drink beer' },
        $MockComic::TEXTS => \%layers,
        $MockComic::FRAMES => [0, 0, 100, 200],
    );
    return $comic;
}


sub get_layer {
    my ($svg, $label) = @_;

    my $node = $svg->documentElement()->firstChild();
    while ($node) {
        if ($node->nodeName() eq 'g' && $node->getAttribute('inkscape:label') eq $label) {
            return $node;
        }
        $node = $node->nextSibling();
    }
    return undef;
}


sub layer_names {
    my ($comic) = @_;
    my @names = sort map { $_->getAttribute('inkscape:label') } $comic->get_all_layers();
    return @names;
}


sub get_all_layers_top_level : Tests {
    my $xml = <<'XML';
<g inkscape:groupmode="layer" id="layer1" inkscape:label="English"/>
<g inkscape:groupmode="layer" id="layer2" inkscape:label="Deutsch"/>
<g inkscape:groupmode="layer" id="layer3" inkscape:label="Español"/>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    is_deeply([layer_names($comic)], ['Deutsch', 'English', 'Español']);
}


sub get_all_layers_nested : Tests {
    my $xml = <<'XML';
<g inkscape:groupmode="layer" id="layer9" inkscape:label="ContainerDeutsch" style="display:none">
    <g style="opacity:0.35" inkscape:label="HintergrundDeutsch" id="g4526" inkscape:groupmode="layer"/>
    <g inkscape:groupmode="layer" id="layer13" inkscape:label="HintergrundTextDeutsch"/>
    <g inkscape:groupmode="layer" id="layer3" inkscape:label="MetaDeutsch"/>
    <g inkscape:groupmode="layer" id="layer2" inkscape:label="Deutsch" style="display:inline"/>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    is_deeply(
        [layer_names($comic)],
        ['ContainerDeutsch', 'Deutsch', 'HintergrundDeutsch', 'HintergrundTextDeutsch', 'MetaDeutsch']);
}


sub get_all_layers_doesnot_pick_up_groupings : Tests {
    my $xml = <<'XML';
<g inkscape:groupmode="layer" id="layer1" inkscape:label="English">
    <g id="g1867" transform="translate(1095.9858,-36.186291)" style="fill:#000000"/>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    is_deeply([layer_names($comic)], ['English']);
}


sub needs_configuration : Tests {
    eval {
        Comic::Out::Copyright->new();
    };
    like($@, qr{Comic::Out::Copyright}i);
    like($@, qr{\btext\b}i);

    eval {
        Comic::Out::Copyright->new(
            'text' => {
            },
        );
    };
    is($@, '');
}


sub configure_style : Tests {
    $copyright = Comic::Out::Copyright->new(
        'text' => {
            'English' => 'beercomics.com',
            'Deutsch' => 'biercomics.de',
        },
        'style' => 'my great style',
    );
    my $comic = make_comic();
    $copyright->generate($comic);
    my $text = get_layer($comic->{dom}, 'CopyrightDeutsch')->getFirstChild();
    is($text->{style}, 'my great style');
}


sub configure_label_and_id_prefix : Tests {
    $copyright = Comic::Out::Copyright->new(
        'text' => {
            'Deutsch' => 'beercomics.de',
        },
        'style' => 'my great style',
        'label_prefix' => 'Label',
        'id_prefix' => 'Id',
    );
    my $comic = make_comic();

    $copyright->generate($comic);

    my $layer = get_layer($comic->{dom}, 'LabelDeutsch');
    is($layer->getAttribute('inkscape:label'), 'LabelDeutsch');
    is($layer->getAttribute('id'), 'IdDeutsch');
}


sub croaks_if_no_text_for_language : Tests {
    $copyright = Comic::Out::Copyright->new(
        'text' => {
            'English' => 'beercomics.com',
        },
        'style' => 'my great style',
    );
    my $comic = make_comic();
    eval {
        $copyright->generate($comic);
    };
    like($@, qr{\btext\b}i, 'should say what is wrong');
    like($@, qr{\bCopyright\b}i, 'should mention module');
    like($@, qr{\bDeutsch\b}i, 'should mention missing language');
}


sub adds_url_and_license : Tests {
    my $comic = make_comic();

    $copyright->generate($comic);

    is(get_layer($comic->{dom}, 'CopyrightDeutsch')->getFirstChild()->textContent(),
        'biercomics.de');
    my @layers = sort map { $_->getAttribute('inkscape:label') } $comic->get_all_layers();
    is_deeply(\@layers, ['CopyrightDeutsch', 'Deutsch', 'Rahmen'], 'wrong layers');
}


sub adds_url_and_license_per_language : Tests {
    my $comic = MockComic::make_comic($MockComic::FRAMES => [0, 0, 100, 100]);

    $copyright->generate($comic);

    is(get_layer($comic->{dom}, "CopyrightDeutsch")->getFirstChild()->textContent(), "biercomics.de");
    is(get_layer($comic->{dom}, "CopyrightEnglish")->getFirstChild()->textContent(), "beercomics.com");

    my @layers = sort map { $_->getAttribute('inkscape:label') } $comic->get_all_layers();
    is_deeply(\@layers, ['CopyrightDeutsch', 'CopyrightEnglish', 'Rahmen'], 'wrong layers');
}


sub one_frame_places_text_at_the_bottom : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::FRAMES => [
            # Frames takes height, width, x, y
            100, 200, 0, 0,
        ],
    );
    is_deeply([2, 198, undef], [Comic::Out::Copyright::_where_to_place_the_text($comic)]);
    $copyright->generate($comic);
    my $text = get_layer($comic->{dom}, 'CopyrightDeutsch')->getFirstChild();
    is($text->getAttribute('x'), 2);
    is($text->getAttribute('y'), 198);
    is($text->getAttribute('transform'), undef);
}


sub two_frames_in_columns_places_text_between : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::FRAMES => [
            # Frames takes height, width, x, y
            100, 100, 0, 0,
            100, 100, 110, 0,
        ],
    );
    is_deeply([102, 0, 'rotate(90, 102, 0)'], [Comic::Out::Copyright::_where_to_place_the_text($comic)]);
    $copyright->generate($comic);
    my $text = get_layer($comic->{dom}, 'CopyrightDeutsch')->getFirstChild();
    is($text->getAttribute('x'), 102);
    is($text->getAttribute('y'), 0);
    is($text->getAttribute('transform'), 'rotate(90, 102, 0)');
}


sub two_frames_in_rows_places_text_between : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::FRAMES => [
            # Frames takes height, width, x, y
            100, 100, 0, 0,
            100, 100, 0, 110,
        ],
    );
    is_deeply([Comic::Out::Copyright::_where_to_place_the_text($comic)], [0, 108, undef]);
    $copyright->generate($comic);
    my $text = get_layer($comic->{dom}, 'CopyrightDeutsch')->getFirstChild();
    is($text->getAttribute('x'), 0);
    is($text->getAttribute('y'), 108);
    is($text->getAttribute('transform'), undef);
}


sub no_frame_places_text_at_the_bottom : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::Copyright::_inkscape_query = sub {
        my ($self, $what) = @_;
        my %dims = ('W' => 100, 'H' => 200, 'X' => 500, 'Y' => '500');
        return $dims{$what};
    };
    use warnings;
    my $comic = MockComic::make_comic(
        $MockComic::FRAMES => [],
    );
    is_deeply([500, 500, undef], [Comic::Out::Copyright::_where_to_place_the_text($comic)]);
    $copyright->generate($comic);
    my $text = get_layer($comic->{dom}, 'CopyrightDeutsch')->getFirstChild();
    is($text->getAttribute('x'), 500);
    is($text->getAttribute('y'), 500);
    is($text->getAttribute('transform'), undef);
}
