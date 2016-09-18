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
    foreach my $i (1..3) {
        MockComic::make_comic(
            $MockComic::PUBLISHED_WHEN => "2016-01-0$i",
            $MockComic::TITLE => {
                $MockComic::DEUTSCH => ['de'],
            },
            $MockComic::TEXTS => {
                $MockComic::DEUTSCH => ['...'],
            },
        );
    }
    is(Comic::counts_of_in('comics', 'Deutsch'), 3, "for Deutsch");
    is(Comic::counts_of_in('comics', 'English'), undef, "for English");
}
