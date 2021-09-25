use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::EmptyTexts;

__PACKAGE__->runtests() unless caller;


my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::EmptyTexts->new();
}


sub non_empty_text_is_ok : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => ['not empty']});
    $check->check($comic);
    ok(1);
}


sub empty_text_found : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => ['']});
    eval {
        $check->check($comic);
    };
    like($@, qr{Empty text in Deutsch}i);
}


sub whitespace_only_text_found : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => [' ']});
    eval {
        $check->check($comic);
    };
    like($@, qr{Empty text in Deutsch}i);
}
