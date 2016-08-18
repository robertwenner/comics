use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub assert_bad {
    my $expected = shift;
    my $err = try_comic(@_);
    like($err, $expected);
    like($err, qr{some_comic\.svg});
}


sub assert_ok {
    is(try_comic(@_), '');
}


sub try_comic {                                          # width height x y
    my $comic = MockComic::make_comic($MockComic::FRAMES => [@_]);
    eval {
        $comic->_check_frames();
    };
    return $@;
}


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


sub aligned_no_frame : Test {
    my $comic = MockComic::make_comic();
    $comic->_check_frames();
    ok(1);
}


sub aligned_single_frame : Test {
    assert_ok(100, 100, 0, 0);
}


sub misaligned_top : Tests {
    assert_bad(qr{align},
        100, 100, 0,   0,
        100, 100, 110, 2);
}


sub misaligned_top_ok_different_row : Test {
    assert_ok(
        100, 100, 0, 0,
        100, 100, 0, 110);
}


sub misaligned_bottom : Tests {
    assert_bad(qr{align},
        100, 100, 0,   0,
        100,  97, 110, 0);
}


sub aligned_left_same_row : Tests {
    assert_ok(
        100, 100,   0, 0,
        100, 100, 110, 0);
}


sub aligned_right_same_row : Test {
    assert_ok(
        100, 100,   0, 0,
        100, 100, 110, 0,
        100, 100, 220, 0);
}


sub misaligned_left_next_row : Tests {
    assert_bad(qr{align},
        100, 100,   0,   0,
        100, 100,   2, 110);
}


sub misaligned_right_next_row : Tests {
    assert_bad(qr{align},
        100, 100,   0,   0,
        102, 100, 110, 110);
}


sub misaligned_top_middle_row : Tests {
    assert_bad(qr{align},
        # top row
        100, 100,   0,   0,
        100, 100, 110,   0,
        100, 100, 220,   0,
        # 2nd row
        100, 100,   0, 110,
        100, 100, 110, 112, # 112 is off
        100, 100, 220, 110,
        # 3rd row
        100, 100,   0, 220,
        100, 100, 110, 220,
        100, 100, 220, 220);
}


sub misaligned_right_middle_column : Tests {
    assert_bad(qr{align},
        # top row
        100, 100,   0,   0,
        100, 100, 110,   0,
        100, 100, 220,   0,
        # 2nd row
        100, 100,   0, 110,
        100, 102, 110, 110, # 102 is off
        100, 100, 220, 110,
        # 3rd row
        100, 100,   0, 220,
        100, 100, 110, 220,
        100, 100, 220, 220);
}


sub overlap_x : Tests {
    assert_bad(qr{overlap},
        100, 100,  0, 0,
        100, 100, 90, 0);
}


sub overlap_y : Tests {
    assert_bad(qr{overlap},
        100, 100, 0, 0,
        100, 100, 0, 90);
}


sub spacing_x_too_close : Tests {
    assert_bad(qr{too close},
        100, 100, 0,   0,
        100, 100, 103, 0);
}


sub spacing_x_too_far : Tests {
    assert_bad(qr{too far},
        100, 100, 0,   0,
        100, 100, 115, 0);
}


sub spacing_x_tolerance : Tests {
    assert_ok(
        100, 100, 0,   0,
        100, 100, 110.87, 0);
}


sub spacing_y_too_close : Tests {
    assert_bad(qr{too close},
        100, 100, 0,   0,
        100, 100, 0, 105);
}


sub spacing_y_too_far : Tests {
    assert_bad(qr{too far},
        100, 100, 0,   0,
        100, 100, 0, 115);
}


sub spacing_y_tolerance : Tests {
    assert_ok(
        100, 100, 0,   0,
        100, 100, 0, 110.87);
}


sub sorts : Tests {
    assert_bad(qr{overlap},
        100, 100, 90, 0,    #  90 - 190
        100, 100, 200, 0,   # 200 - 300
        100, 100, 0, 0);    #   0 - 100
}


sub normalizes_y_for_sorting : Tests {
    assert_ok(
        100, 100, 0, 1,
        100, 100, 111, 0);
}


sub negative_coordinates : Tests {
    assert_ok(
        100, 100, -500, -500,   # -500 - -400
        100, 100, -610, -500);  # -610 - -510
}


sub double : Tests {
    assert_ok(
        100, 100, 0.5, 0.5, # 0.5 - 100.5 
        100, 100, 111, 0);  # 111 - 211
}


sub aligned_left_multiple_columns : Tests {
    assert_ok(
        100, 100, 0, 0,
        100, 100, 110, 0,
        100, 210, 0, 110);
}
