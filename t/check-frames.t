use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub width_ok : Test {
    my $comic = MockComic::make_comic($MockComic::FRAMEWIDTH => 1.25);
    $comic->_check_frames();
    ok(1);
}


sub width_too_narrow : Test {
    my $comic = MockComic::make_comic($MockComic::FRAMEWIDTH => 0.99);
    eval {
        $comic->_check_frames();
    };
    like($@, qr{too narrow}i);
}


sub width_too_wide : Test {
    my $comic = MockComic::make_comic($MockComic::FRAMEWIDTH => 1.51);
    eval {
        $comic->_check_frames();
    };
    like($@, qr{too wide}i);
}
