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


my $comic;

sub make_frames {
    $comic = MockComic::make_comic($MockComic::FRAMES => [@_]);
    $comic->_find_frames();
    return $comic->{frame_tops};
}


sub no_frame : Test {
    is_deeply([], make_frames());
}


sub single_frame : Test {
    is_deeply([0], make_frames(
        # height, width, x, y
        0, 0, 0, 0));
}


sub frames_same_height : Test {
    is_deeply([0], make_frames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, 0));
}


sub frames_almost_same_height : Test {
    is_deeply([0], make_frames(
        # height, width, x, y
        0, 0, 0, 0,   
        0, 0, 0, $Comic::FRAME_TOLERANCE - 1,   
        0, 0, 0, -1 * $Comic::FRAME_TOLERANCE + 1));
}


sub two_rows_of_frames : Test {
    is_deeply([0, 100], make_frames(
        # height, width, x, y
        0, 0, 0, 0,     
        0, 0, 0, 0,
        0, 0, 0, 100,
        0, 0, 0, 100));
}


sub three_rows_of_frames : Test {
    is_deeply([0, 100, 200], make_frames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, 200,
        0, 0, 0, 100));
}


sub pos_to_frame : Tests {
    make_frames(
        0, 0, 0, 0,
        0, 0, 0, 100,
        0, 0, 0, 200);
    is(0, $comic->_pos_to_frame(-1));
    is(1, $comic->_pos_to_frame(1));
    is(1, $comic->_pos_to_frame(99));
    is(2, $comic->_pos_to_frame(100));
    is(2, $comic->_pos_to_frame(199));
    is(3, $comic->_pos_to_frame(200));
    is(3, $comic->_pos_to_frame(1000));
}
