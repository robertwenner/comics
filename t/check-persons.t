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


sub no_persons_meta_data : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    $comic->_check_persons('English');
    is_deeply($comic->{warnings}, ["No persons metadata at all"]);
}


sub no_persons_in_array : Tests {    
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::WHO => {$MockComic::ENGLISH => []});
    $comic->_check_persons('English');
    is_deeply($comic->{warnings}, []);
}


sub empty_name : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::WHO => {$MockComic::ENGLISH => [' ']});
    $comic->_check_persons('English');
    is_deeply($comic->{warnings}, ['Empty person name in English']);
}


sub same_number_of_persons : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => ['Max', 'Paul', 'Lighty drinker'],
            $MockComic::DEUTSCH => ['Max', 'Paul', 'Lighty-Trinker']
        });
    $comic->_check_persons('English');
    is_deeply($comic->{warnings}, []);
}


sub different_number_of_persons : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => ['Max'],
            $MockComic::DEUTSCH => ['Max', 'Paul']
        });
    $comic->_check_persons('English');
    is_deeply($comic->{warnings}, ['Different number of persons in English and Deutsch']);
}
