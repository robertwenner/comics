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


sub make_texts {
    my (@texts) = @_;

    my $xml =<<'XML';
    <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="Deutsch"
     style="display:inline">
XML
    for(my $i = 0; $i < @texts; $i += 2) {
        my $x = $texts[$i];
        my $y = $texts[$i + 1];
        $xml .= <<TEXT;
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:125%;font-family:RW5;-inkscape-font-specification:'RW Medium';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       x="$x"
       y="$y"
       id="text16220"
       sodipodi:linespacing="125%"><tspan
         sodipodi:role="line"
         id="tspan16222"
         x="$x"
         y="$y">Text $x / $y</tspan></text>
TEXT
    }
    $xml .= '</g>';
    my $comic = MockComic::make_comic(
        $MockComic::XML => $xml,
        $MockComic::FRAMES => [
            100, 100, 0, 0,
            100, 100, 0, 100,
        ],
    );
    $comic->_find_frames();
    return $comic;
}


sub one_text : Test {
    is_deeply([make_texts(0, 0)->texts_in_layer("Deutsch")],
        ["Text 0 / 0"]);
}


sub different_x : Test {
    is_deeply([make_texts(0, 0, 10, 0)->texts_in_layer("Deutsch")],
        ["Text 0 / 0", "Text 10 / 0"]);
}


sub different_y : Test {
    is_deeply([make_texts(0, 0, 0, 10)->texts_in_layer("Deutsch")],
        ["Text 0 / 0", "Text 0 / 10"]);
}


sub different_x_and_y : Test {
    is_deeply([make_texts(0, 0, 10, 10)->texts_in_layer("Deutsch")],
        ["Text 0 / 0", "Text 10 / 10"]);
}


sub different_frames : Test {
    is_deeply([make_texts(0, 110, 10, 10)->texts_in_layer("Deutsch")],
        ["Text 10 / 10", "Text 0 / 110"]);
}
