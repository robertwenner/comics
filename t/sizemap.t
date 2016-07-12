use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub make_comic {
    my ($width, $height) = @_;

    my $comic = MockComic::make_comic();
    $comic->{height} = $height;
    $comic->{width} = $width;
    return $comic;
}


sub sorting : Tests {
    my $a = make_comic(10, 100);
    my $b = make_comic(20, 90);
    my $c = make_comic(30, 80);

    is_deeply([$c, $b, $a], [sort Comic::_by_height ($b, $a, $c)]);
    is_deeply([$a, $b, $c], [sort Comic::_by_width ($b, $a, $c)]);
}
