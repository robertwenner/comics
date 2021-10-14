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


sub make_big_png {
    my $png = '';
    foreach my $i (0 .. 132000) {
        $png .= 'x' x 76 . "\n";
    }
    return '<image href="' . $png . '"/>';
}


sub load_huge : Tests {
    eval {
        MockComic::make_comic($MockComic::XML => make_big_png());
    };
    is("", $@, "should load huge XML");
}
