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


sub one_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { 'English' => 'Drinking beer' }
    );
    is_deeply([$comic->languages()], ['English']);
}


sub many_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
            'Español' => 'Tomar cerveca',
        },
    );
    is_deeply([sort $comic->languages()], ['Deutsch', 'English', 'Español']);
}


sub no_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {},
        $MockComic::TAGS => { $MockComic::ENGLISH => [], },
    );
    is_deeply([sort $comic->languages()], []);
}
