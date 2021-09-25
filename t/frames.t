use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Out::Copyright;


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


sub assert_frames_xy {
    my @xy = @_;
    my $i = 0;
    foreach my $frame ($comic->all_frames_sorted()) {
        is($frame->getAttribute('x'), shift @xy, "x $i");
        is($frame->getAttribute('y'), shift @xy, "y $i");
        $i++;
    }
}


sub no_frame : Tests {
    is_deeply([], make_frames());
}


sub single_frame : Tests {
    is_deeply([0], make_frames(
        # height, width, x, y
        0, 0, 0, 0));
}


sub frames_same_height : Tests {
    is_deeply([0], make_frames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, 0));
}


sub frames_almost_same_height : Tests {
    is_deeply([0], make_frames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, $Comic::Consts::FRAME_TOLERANCE - 1,
        0, 0, 0, -1 * $Comic::Consts::FRAME_TOLERANCE + 1));
}


sub two_rows_of_frames : Tests {
    is_deeply([0, 100], make_frames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 100,
        0, 0, 0, 100));
}


sub three_rows_of_frames : Tests {
    is_deeply([0, 100, 200], make_frames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, 200,
        0, 0, 0, 100));
}


sub pos_to_frame : Tests {
    make_frames(
        # height, width, x, y
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


sub sorting_y : Tests {
    make_frames(
        # height, width, x, y
        0, 0, 0,   0,
        0, 0, 0,  10,
        0, 0, 0, -10);
    assert_frames_xy(0, -10, 0, 0, 0, 10);
}


sub sorting_negative_y : Tests {
    make_frames(
        # height, width, x, y
        0, 0, 0, -500,
        0, 0, 0, -300,
        0, 0, 0, -100);
    assert_frames_xy(0, -500, 0, -300, 0, -100);
}



sub sorting_x : Tests {
    make_frames(
        # height, width, x, y
        0, 0,   0, 0,
        0, 0, -10, 0,
        0, 0,  10, 0);
    assert_frames_xy(-10, 0, 0, 0, 10, 0);
}


sub sorting_xy : Tests {
    make_frames(
        # height, width, x, y
        0, 0,   0,   0,
        0, 0,  10,  10,
        0, 0, 100,  10,
        0, 0,  10, 100,
        0, 0,   0, -10,
        0, 0, -10, -10);
    assert_frames_xy(-10, -10, 0, -10, 0, 0, 10, 10, 100, 10, 10, 100);
}


sub bottom_right_corner : Tests {
    make_frames(
        # height, width, x, y
        10, 10,  0,   0,
        10, 10, 15,   0,
        10, 10, 30,   0,
        10, 10,  0, -15,
        10, 10, 15, -15,
        10, 10, 30, -15);
    is_deeply([Comic::Out::Copyright::_bottom_right($comic)], [40, 0]);
}


sub sorts_numerically_ints : Tests {
    make_frames(
        100, 100, 535, 680,
        100, 100, 845, 680,
        100, 100, 90, 680);
    my @sorted = map { $_->getAttribute('x') } $comic->all_frames_sorted();
    is_deeply([@sorted], [90, 535, 845]);
}



sub sorts_numerically_floats : Tests {
    make_frames(
        100, 100, 535.66895, 679.83606,
        100, 100, 845.66669, 679.8938,
        100, 100, 90.664955, 680.06812);
    my @sorted = map { $_->getAttribute('x') } $comic->all_frames_sorted();
    is_deeply([@sorted], [90.664955, 535.66895, 845.66669]);
}
