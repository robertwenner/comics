use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub setup : Test(setup) {
    MockComic::set_up();
}


sub language_code_de : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken'
        });
    is_deeply({'Deutsch' => 'de'}, {$comic->_language_codes()});
}


sub language_code_en : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Drinking beer'
        });
    is_deeply({'English' => 'en'}, {$comic->_language_codes()});
}


sub language_code_es : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Español' => 'Tomando cerveza',
        });
    is_deeply({'Español' => 'es'}, {$comic->_language_codes()});
}


sub language_code_unknown : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Pimperanto' => 'WTF?!'
        });
    eval {
        $comic->_language_codes();
    };
    like($@, qr{cannot find language code for 'Pimperanto'}i);
}


sub language_code_for_all_languages_in_comic : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Español' => 'Cerveza',
            'English' => 'Beer',
            'Italiano' => 'Birra',
            'Deutsch' => 'Bier',
        });
    is_deeply({
            'Deutsch' => 'de',
            'English' => 'en',
            'Español' => 'es',
            'Italiano' => 'it',
        },
        {
            $comic->_language_codes()
        });
}
