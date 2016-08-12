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
