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

sub frame_tops {
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
    is_deeply([], frame_tops());
}


sub single_frame : Tests {
    is_deeply([0, 100], frame_tops(
        # height, width, x, y
        100, 100, 0, 0));
}


sub frames_same_height : Tests {
    is_deeply([0, 100], frame_tops(
        # height, width, x, y
        100, 100, 0, 0,
        100, 100, 0, 0));
}


sub frames_almost_same_height : Tests {
    is_deeply([0, 100], frame_tops(
        # height, width, x, y
        100, 100, 0, 0,
        100, 100, 0, $Comic::Consts::FRAME_TOLERANCE - 1,
        100, 100, 0, -1 * $Comic::Consts::FRAME_TOLERANCE + 1));
}


sub two_rows_of_frames : Tests {
    is_deeply([0, 100, 200], frame_tops(
        # height, width, x, y
        100, 100, 0, 0,
        100, 100, 0, 0,
        100, 100, 0, 100,
        100, 100, 0, 100));
}


sub three_rows_of_frames : Tests {
    is_deeply([0, 100, 200, 300], frame_tops(
        # height, width, x, y
        100, 100, 0, 0,
        100, 100, 0, 200,
        100, 100, 0, 100));
}


sub pos_to_frame : Tests {
    frame_tops(
        # height, width, x, y
        100, 100, 0, 0,
        100, 100, 0, 100,
        100, 100, 0, 200);
    is(0, $comic->_pos_to_frame(-1));
    is(1, $comic->_pos_to_frame(1));
    is(1, $comic->_pos_to_frame(99));
    is(2, $comic->_pos_to_frame(100));
    is(2, $comic->_pos_to_frame(199));
    is(3, $comic->_pos_to_frame(200));
    is(4, $comic->_pos_to_frame(1000));
}


sub sorting_y : Tests {
    frame_tops(
        # height, width, x, y
        0, 0, 0,   0,
        0, 0, 0,  10,
        0, 0, 0, -10);
    assert_frames_xy(0, -10, 0, 0, 0, 10);
}


sub sorting_negative_y : Tests {
    frame_tops(
        # height, width, x, y
        0, 0, 0, -500,
        0, 0, 0, -300,
        0, 0, 0, -100);
    assert_frames_xy(0, -500, 0, -300, 0, -100);
}



sub sorting_x : Tests {
    frame_tops(
        # height, width, x, y
        0, 0,   0, 0,
        0, 0, -10, 0,
        0, 0,  10, 0);
    assert_frames_xy(-10, 0, 0, 0, 10, 0);
}


sub sorting_xy : Tests {
    frame_tops(
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
    frame_tops(
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
    frame_tops(
        100, 100, 535, 680,
        100, 100, 845, 680,
        100, 100, 90, 680);
    my @sorted = map { $_->getAttribute('x') } $comic->all_frames_sorted();
    is_deeply([@sorted], [90, 535, 845]);
}



sub sorts_numerically_floats : Tests {
    frame_tops(
        100, 100, 535.66895, 679.83606,
        100, 100, 845.66669, 679.8938,
        100, 100, 90.664955, 680.06812);
    my @sorted = map { $_->getAttribute('x') } $comic->all_frames_sorted();
    is_deeply([@sorted], [90.664955, 535.66895, 845.66669]);
}


sub uses_default_frame_layer_name_if_not_configured : Tests {
    $comic = MockComic::make_comic($MockComic::XML => <<XML);
        <g inkscape:groupmode="layer" inkscape:label="Frames">
            <rect width="100" height="100" x="0" y="0"/>
        </g>
XML
    $comic->{settings}->{LayerNames}->{Frames} = undef;

    my @frames = $comic->all_frames_sorted();

    is_deeply([@frames], ['<rect width="100" height="100" x="0" y="0"/>']);
}


sub configure_frame_layer_name : Tests {
    $comic = MockComic::make_comic($MockComic::XML => <<XML);
        <g inkscape:groupmode="layer" inkscape:label="Panels">
            <rect width="100" height="100" x="0" y="0"/>
        </g>
XML
    $comic->{settings}->{LayerNames}->{Frames} = 'Panels';

    my @frames = $comic->all_frames_sorted();

    is_deeply([@frames], ['<rect width="100" height="100" x="0" y="0"/>']);
}


sub rejects_empty_frame_layer_name : Tests {
    $comic = MockComic::make_comic();
    $comic->{settings}->{LayerNames}->{Frames} = '';

    eval {
        $comic->all_frames_sorted();
    };
    like($@, qr{empty}, 'should mention what the problem is');
    like($@, qr{LayerNames\.Frames}, 'should mention where the problem is');
}


sub complains_if_no_frame_layer_found : Tests {
    $comic = MockComic::make_comic();
    $comic->{settings}->{LayerNames}->{Frames} = 'Panels';

    my @frames = $comic->all_frames_sorted();
    # Check that the comic doesn't get flooded in the no frame layer warning
    $comic->all_frames_sorted();
    $comic->all_frames_sorted();

    is_deeply([@frames], []);
    is_deeply($comic->{warnings}, ["No 'Panels' layer"]);
}
