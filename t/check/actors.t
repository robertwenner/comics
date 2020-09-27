use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::Actors;

__PACKAGE__->runtests() unless caller;

my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::Actors->new();
}


sub no_actors_meta_data : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TITLE => {$MockComic::ENGLISH => 'Beer'});
    $check->check($comic);
    is_deeply($comic->{warnings}, ["No $MockComic::ENGLISH actors metadata at all"]);
}


sub no_actors_in_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TITLE => {$MockComic::ENGLISH => 'Beer'},
        $MockComic::WHO => {$MockComic::ENGLISH => []});
    $check->check($comic);
    is_deeply($comic->{warnings}, []);
}


sub empty_name : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TITLE => {$MockComic::ENGLISH => 'Beer'},
        $MockComic::WHO => {$MockComic::ENGLISH => [' ']});
    $check->check($comic);
    is_deeply($comic->{warnings}, ['Empty actor name in English']);
}


sub same_number_of_actors : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => ['Max', 'Paul', 'Lighty drinker'],
            $MockComic::DEUTSCH => ['Max', 'Paul', 'Lighty-Trinker'],
        });
    $check->check($comic);
    is_deeply($comic->{warnings}, []);
}


sub different_number_of_actors : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => ['Max'],
            $MockComic::DEUTSCH => ['Max', 'Paul']
        });
    $check->check($comic);
    is_deeply($comic->{warnings},
        ["Different number of actors in $MockComic::DEUTSCH and $MockComic::ENGLISH"]);
}
