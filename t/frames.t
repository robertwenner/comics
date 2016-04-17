use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub makeFrames {
    my (@frames) = @_;

    *Comic::_slurp = sub {
        my $xml = <<XML;
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   width="744.09448"
   height="1052.3622"
   id="svg2"
   version="1.1"
   inkscape:version="0.91 r"
   viewBox="0 0 744.09448 1052.3622">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:groupmode="layer"
     id="layer6"
     inkscape:label="Rahmen"
     sodipodi:insensitive="true">
XML

        for (my $i = 0; $i < @frames; $i += 4) {
            my ($width, $height, $x, $y) = @frames[$i, $i + 1, $i + 2, $i + 3];
            $xml .= <<XML;
    <rect
       style="display:inline;fill:none;stroke:#000000;stroke-width:1.08581364;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
       id="rect6486"
       width="$width"
       height="$height"
       x="$x"
       y="$y"/>
XML
        }
        $xml .= <<XML;
  </g>
</svg>    
XML
        return $xml;
    };
    *Comic::_mtime = sub {
        return 0;
    };
    $comic = Comic->new('whatever');
    $comic->_findFrames();
    return $comic->{frameTops};
}


sub noFrame : Test {
    is_deeply([], makeFrames());
}


sub singleFrame : Test {
    is_deeply([0], makeFrames(
        # height, width, x, y
        0, 0, 0, 0));
}


sub framesSameHeight : Test {
    is_deeply([0], makeFrames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, 0));
}


sub framesAlmostSameHeight : Test {
    is_deeply([0], makeFrames(
        # height, width, x, y
        0, 0, 0, 0,   
        0, 0, 0, Comic::FRAME_TOLERANCE - 1,   
        0, 0, 0, -1 * Comic::FRAME_TOLERANCE + 1));
}


sub twoRowsOfFrames : Test {
    is_deeply([0, 100], makeFrames(
        # height, width, x, y
        0, 0, 0, 0,     
        0, 0, 0, 0,
        0, 0, 0, 100,
        0, 0, 0, 100));
}


sub threeRowsOfFrames : Test {
    is_deeply([0, 100, 200], makeFrames(
        # height, width, x, y
        0, 0, 0, 0,
        0, 0, 0, 200,
        0, 0, 0, 100));
}


sub posToFrame : Tests {
    makeFrames(
        0, 0, 0, 0,
        0, 0, 0, 100,
        0, 0, 0, 200);
    is(0, $comic->_posToFrame(-1));
    is(1, $comic->_posToFrame(1));
    is(1, $comic->_posToFrame(99));
    is(2, $comic->_posToFrame(100));
    is(2, $comic->_posToFrame(199));
    is(3, $comic->_posToFrame(200));
    is(3, $comic->_posToFrame(1000));
}
