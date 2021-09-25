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
        'Text' =>  {
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


sub copy_svg : Tests {
    my $comic = make_comic();
    my $svg = $comic->copy_svg();
    is($svg, $comic->{dom}, 'should be equal');
    is_deeply($svg, $comic->{dom}, 'should be deeply equal');
    ok($comic->{dom} != $svg, 'should not be the same');
}


sub can_safely_modify_copy : Tests {
    my $comic = make_comic();
    my $svg = $comic->copy_svg();
    $svg->documentElement()->addNewChild(undef, 'foo');
    isnt($svg, $comic->{dom}, 'should not be equal anymore');
}


sub needs_configuration : Tests {
    eval {
        Comic::Out::Copyright->new();
    };
    like($@, qr{Comic::Out::Copyright configuration}i);
    like($@, qr{\bText\b}i);

    eval {
        Comic::Out::Copyright->new(
            'Text' => {
            },
        );
    };
    is($@, '');
}


sub configure_style : Tests {
    $copyright = Comic::Out::Copyright->new(
        'Text' => {
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


sub croaks_if_no_style : Tests {
    $copyright = Comic::Out::Copyright->new(
        'Text' => {
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
}


sub adds_url_and_license_per_language : Tests {
    my $comic = MockComic::make_comic($MockComic::FRAMES => [0, 0, 100, 100]);
    $copyright->generate($comic);
    is(get_layer($comic->{dom}, "CopyrightDeutsch")->getFirstChild()->textContent(), "biercomics.de");
    is(get_layer($comic->{dom}, "CopyrightEnglish")->getFirstChild()->textContent(), "beercomics.com");
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
