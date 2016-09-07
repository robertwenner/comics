use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub empty_text_found : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => ['']});
    eval {
        $comic->_texts_for($MockComic::DEUTSCH);
    };
    like($@, qr{Empty text in Deutsch with ID $MockComic::TEXT_ID}i);
}


sub whitespace_only_text_found : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => [' ']});
    eval {
        $comic->_texts_for($MockComic::DEUTSCH);
    };
    like($@, qr{Empty text in Deutsch with ID $MockComic::TEXT_ID}i);
}


sub empty_text_other_language_ignored : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => ['']});
    eval {
        $comic->_texts_for("English");
    };
    is($@, '');
}


sub duplicated_text_in_other_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => [' Paul shows Max his bym.'],
            $MockComic::ENGLISH => ['Paul shows Max his bym. '],
    });
    eval {
        $comic->_check_transcript("English");
    };
    like($@, qr{^some_comic.svg:}, 'should include file name');
    like($@, qr{duplicated text}, 'wrong error message');
    like($@, qr{'Paul shows Max his bym\.'}, 'should mention duplicated text');
    like($@, qr{English and Deutsch}, 'should mention offending languages');
}


sub duplicated_text_in_other_language_ignores_text_order : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['a', 'b', 'c'],
            $MockComic::ENGLISH => ['z', 'x', 'a'],
    });
    eval {
        $comic->_check_transcript("English");
    };
    like($@, qr{duplicated text});
}


sub duplicated_text_in_other_language_ignores_names : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['Max:', 'guck mal', ' Paul:', 'was?'],
            $MockComic::ENGLISH => ['Max:', 'look at this', 'Paul: ', 'what?'],
        });
    eval {
        $comic->_check_transcript("English");
    };
    is($@, '');
}


sub duplicated_text_in_other_language_trailing_colon_no_speaker : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['Paul:', 'bla', 'The microphone comes to live:'],
            $MockComic::ENGLISH => ['Paul:', 'blah', 'The microphone comes to live:'],
    });
    eval {
        $comic->_check_transcript("English");
    };
    like($@, qr{duplicated text});
}


sub last_text_is_speaker_indicator : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['Max:', 'blah', 'Paul:'],
    });
    eval {
        $comic->_check_transcript("Deutsch");
    };
    like($@, qr{speaker's text missing after 'Paul:'});
}
