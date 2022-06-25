use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Comic::Consts;
use Comic::Check::Frames;

__PACKAGE__->runtests() unless caller;


my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::Frames->new();
}


sub assert_bad {
    my $expected = shift;
    my $comic = try_comic(@_);
    like(${$comic->{warnings}}[0], $expected);
}


sub assert_ok {
    my $comic = try_comic(@_);
    is_deeply($comic->{warnings}, []);
}


sub try_comic {
    # params is a bunch of width height x y numbers
    my $comic = MockComic::make_comic($MockComic::FRAMES => [@_]);
    $check->check($comic);
    return $comic;
}



sub uses_defaults : Tests {
    $check = Comic::Check::Frames->new();
    is($check->{'FRAME_ROW_HEIGHT'}, $Comic::Consts::FRAME_ROW_HEIGHT, 'wrong frame row height');
    is($check->{'FRAME_SPACING'}, $Comic::Consts::FRAME_SPACING, 'wrong frame spacing');
    is($check->{'FRAME_SPACING_TOLERANCE'}, $Comic::Consts::FRAME_SPACING_TOLERANCE, 'wrong spacing tolerance');
    is($check->{'FRAME_TOLERANCE'}, $Comic::Consts::FRAME_TOLERANCE, 'wrong frame tolerance');
    is($check->{'FRAME_WIDTH'}, $Comic::Consts::FRAME_WIDTH, 'wrong frame width');
    is($check->{'FRAME_WIDTH_DEVIATION'}, $Comic::Consts::FRAME_WIDTH_DEVIATION, 'wrong frame width deviation');
}


sub override_defaults : Tests {
    $check = Comic::Check::Frames->new(
        'FRAME_ROW_HEIGHT' => 100,
        'FRAME_SPACING' => 200,
        'FRAME_SPACING_TOLERANCE' => 300,
        'FRAME_TOLERANCE' => 400,
        'FRAME_WIDTH' => 500,
        'FRAME_WIDTH_DEVIATION' => 500,
    );
    is($check->{'FRAME_ROW_HEIGHT'}, 100, 'wrong frame row height');
    is($check->{'FRAME_SPACING'}, 200, 'wrong frame spacing');
    is($check->{'FRAME_SPACING_TOLERANCE'}, 300, 'wrong spacing tolerance');
    is($check->{'FRAME_TOLERANCE'}, 400, 'wrong frame tolerance');
    is($check->{'FRAME_WIDTH'}, 500, 'wrong frame width');
    is($check->{'FRAME_WIDTH_DEVIATION'}, 500, 'wrong frame width deviation');
}


sub bad_svg_no_stroke : Tests {
    my $frame = <<"FRAME";
  <g
     inkscape:groupmode="layer"
     inkscape:label="Rahmen">
    <rect
       style="display:inline;fill:none;stroke:#000000;stroke-opacity:1"
       id="rect6486"
       width="100"
       height="100"
       x="0"
       y="0"/>
  </g>
FRAME
    my $comic = MockComic::make_comic($MockComic::XML => $frame);
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{Cannot find width});
}


sub width_ok : Tests {
    my $comic = MockComic::make_comic($MockComic::FRAMEWIDTH => 1.25);

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}


sub width_too_narrow : Tests {
    my $comic = MockComic::make_comic($MockComic::FRAMEWIDTH => 0.99);

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{too narrow}i);
}


sub width_too_wide : Tests {
    my $comic = MockComic::make_comic($MockComic::FRAMEWIDTH => 1.51);

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{too wide}i);
}


sub aligned_no_frame : Tests {
    my $comic = MockComic::make_comic();

    $check->check($comic);

    is_deeply($comic->{warnings}, ["No 'Rahmen' layer"]);
}


sub aligned_single_frame : Tests {
    assert_ok(100, 100, 0, 0);
}


sub misaligned_top : Tests {
    assert_bad(qr{align},
        100, 100, 0,   0,
        100, 100, 110, 2);
}


sub misaligned_top_ok_different_row : Tests {
    assert_ok(
        100, 100, 0, 0,
        100, 100, 0, -110);
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


sub aligned_right_same_row : Tests {
    assert_ok(
        100, 100,   0, 0,
        100, 100, 110, 0,
        100, 100, 220, 0);
}


sub misaligned_left_next_row : Tests {
    assert_bad(qr{left.+align},
        100, 100,   0,   0,
        100, 100,   2, 110);
}


sub misaligned_right_middle_row : Tests {
    assert_bad(qr{right.+align},
        100, 100,   0,   0,
        102, 100,   0, 110,
        100, 100,   0, 220);
}


sub misaligned_right_last_row : Tests {
    assert_bad(qr{right.+align},
        100, 100,   0,   0,
        102, 100,   0, 110);
}


sub misaligned_top_middle_row_too_close : Tests {
    assert_bad(qr{bottoms not aligned},
        # top row
        100, 100,   0,   0,
        100, 100, 110,   0,
        100, 100, 220,   0,
        # 2nd row
        100, 100,   0, 110,
        100, 100, 110, 108, # width, height, x, y --- 108 is off
        100, 100, 220, 110,
        # 3rd row
        100, 100,   0, 220,
        100, 100, 110, 220,
        100, 100, 220, 220);
}


sub misaligned_top_middle_row_too_far: Tests {
    assert_bad(qr{bottoms not aligned},
        # top row
        100, 100,   0,   0,
        100, 100, 110,   0,
        100, 100, 220,   0,
        # 2nd row
        100, 100,   0, 110,
        100, 100, 110, 113, # width, height, x, y --- 113 is off
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


sub two_small_frames_next_to_each_other_one_wide_frame : Tests {
    assert_ok( # width height x y
        100, 100, 0, 0,
        100, 100, 110, 0,
        210, 100, 0, 110);
}
