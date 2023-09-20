use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use Comic::Settings;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub setup : Test(setup) {
    MockComic::set_up();
}


sub language_code_de : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken'
        });
    is_deeply({'Deutsch' => 'de'}, {$comic->language_codes()});
}


sub language_code_en : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Drinking beer',
        });
    is_deeply({'English' => 'en'}, {$comic->language_codes()});
}


sub language_code_es : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Español' => 'Tomando cerveza',
        });
    is_deeply({'Español' => 'es'}, {$comic->language_codes()});
}


sub language_code_unknown : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Pimperanto' => 'WTF?!',
        },
        $MockComic::SETTINGS => {
            $MockComic::DOMAINS => {
                'Pimperanto' => 'wtf.com',
            },
            $Comic::Settings::CHECKS => [],
            'Paths' => {
                'siteComics' => 'comics/',
                'published' => 'generated/web/',
                'unpublished' => 'generated/backlog/',
            },
        });
    eval {
        $comic->language_codes();
    };
    like($@, qr{cannot find language code for 'Pimperanto'}i);
}


sub language_code_for_all_languages_in_comic : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Español' => 'Cerveza',
            'English' => 'Beer',
            'Deutsch' => 'Bier',
        });
    is_deeply({
            'Deutsch' => 'de',
            'English' => 'en',
            'Español' => 'es',
        },
        {
            $comic->language_codes()
        });
}


sub croaks_on_language_without_domain : Tests {
    eval {
        MockComic::make_comic(
            $MockComic::TITLE => {
                'Pimperanto' => 'WTF?!'
            });
    };
    like($@, qr{no domain for Pimperanto}i);
}
