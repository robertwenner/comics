use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub make_comic {
    my %layers = (
        $MockComic::DEUTSCH => ['blah'],
#        $MockComic::META_DEUTSCH => [],
#        $MockComic::ENGLISH => [],
#        $MockComic::META_ENGLISH => [],
#        $MockComic::HINTERGRUND => [],
#        $MockComic::FIGUREN => [],
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
    my $svg = $comic->_copy_svg();
    is($svg, $comic->{dom}, 'should be equal');
    is_deeply($svg, $comic->{dom}, 'should be deeply equal');
    ok($comic->{dom} != $svg, 'should not be the same');
}


sub can_safely_modify_copy : Tests {
    my $comic = make_comic();
    my $svg = $comic->_copy_svg();
    $svg->documentElement()->addNewChild(undef, 'foo');
    isnt($svg, $comic->{dom}, 'should not be equal anymore');
}


sub adds_url_and_license : Tests {
    my $comic = make_comic();
    $comic->_insert_url($comic->{dom}, 'Deutsch');
    is(get_layer($comic->{dom}, 'LicenseDeutsch')->getFirstChild()->textContent(),
        'biercomics.de — CC BY-NC-SA 4.0');
}


sub adds_url_and_license_per_language : Tests {
    my $comic = MockComic::make_comic($MockComic::FRAMES => [0, 0, 100, 100]);
    $comic->_insert_url($comic->{dom}, $MockComic::DEUTSCH);
    $comic->_insert_url($comic->{dom}, $MockComic::ENGLISH);
    is(get_layer($comic->{dom}, "LicenseDeutsch")->getFirstChild()->textContent(), "biercomics.de — CC BY-NC-SA 4.0");
    is(get_layer($comic->{dom}, "LicenseEnglish")->getFirstChild()->textContent(), "beercomics.com — CC BY-NC-SA 4.0");
}


sub one_frame_places_text_at_the_bottom : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::FRAMES => [
            # Frames takes height, width, x, y
            100, 200, 0, 0,
        ],
    );
    is_deeply([2, 198, undef], [$comic->_where_to_place_the_text()]);
    $comic->_insert_url($comic->{dom}, 'Deutsch');
    my $text = get_layer($comic->{dom}, 'LicenseDeutsch')->getFirstChild();
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
    is_deeply([102, 0, 'rotate(90, 102, 0)'], [$comic->_where_to_place_the_text()]);
    $comic->_insert_url($comic->{dom}, 'Deutsch');
    my $text = get_layer($comic->{dom}, 'LicenseDeutsch')->getFirstChild();
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
    is_deeply([$comic->_where_to_place_the_text()], [0, 108, undef]);
    $comic->_insert_url($comic->{dom}, 'Deutsch');
    my $text = get_layer($comic->{dom}, 'LicenseDeutsch')->getFirstChild();
    is($text->getAttribute('x'), 0);
    is($text->getAttribute('y'), 108);
    is($text->getAttribute('transform'), undef);
}


sub no_frame_places_text_at_the_bottom : Tests {
    no warnings qw/redefine/;
    local *Comic::_inkscape_query = sub {
        my ($self, $what) = @_;
        my %dims = ('W' => 100, 'H' => 200, 'X' => 500, 'Y' => '500');
        return $dims{$what};
    };
    use warnings;
    my $comic = MockComic::make_comic(
        $MockComic::FRAMES => [],
    );
    is_deeply([500, 500, undef], [$comic->_where_to_place_the_text()]);
    $comic->_insert_url($comic->{dom}, 'Deutsch');
    my $text = get_layer($comic->{dom}, 'LicenseDeutsch')->getFirstChild();
    is($text->getAttribute('x'), 500);
    is($text->getAttribute('y'), 500);
    is($text->getAttribute('transform'), undef);
}
