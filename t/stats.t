use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub comic_counts_per_language : Tests {
    local *Comic::_svg_to_png = sub {
        # ignore
    };
    local *Comic::_get_png_info = sub {
        # ignore
    };
    local *Comic::_write_temp_svg_file = sub {
       # ignore
    };
    foreach my $i (1..3) {
        MockComic::make_comic(
            $MockComic::PUBLISHED => "2016-01-$i",
            $MockComic::TITLE => {
                $MockComic::DEUTSCH => ['de'],
            },
            $MockComic::TEXTS => {
                $MockComic::DEUTSCH => ['...'],
            },
        )->export_png("English" => "en", "Deutsch" => "de");
    }
    is(Comic::counts_of_in('comics', 'Deutsch'), 3, "for Deutsch");
    is(Comic::counts_of_in('comics', 'English'), undef, "for English");
}
