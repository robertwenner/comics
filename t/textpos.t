use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub makeTexts {
    my (@texts) = @_;

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
    <rect
       style="display:inline;fill:none;stroke:#000000;stroke-width:1.08581364;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
       id="rect6486"
       width="100"
       height="100"
       x="0"
       y="0"/>
    <rect
       style="display:inline;fill:none;stroke:#000000;stroke-width:1.08581364;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
       id="rect6486"
       width="100"
       height="100"
       x="0"
       y="100"/>
  </g>
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
$xml .= <<XML;
  </g>
</svg>
XML
        return $xml;
    };
    $comic = Comic->new('whatever');
    $comic->_findFrames();
    return $comic;
}


sub oneText : Test {
    is_deeply([makeTexts(0, 0)->_textsFor("Deutsch")], 
        ["Text 0 / 0"]);
}


sub differentX : Test {
    is_deeply([makeTexts(0, 0, 10, 0)->_textsFor("Deutsch")],
        ["Text 0 / 0", "Text 10 / 0"]);
}


sub differentY : Test {
    is_deeply([makeTexts(0, 0, 0, 10)->_textsFor("Deutsch")],
        ["Text 0 / 0", "Text 0 / 10"]);
}


sub differentXandY : Test {
    is_deeply([makeTexts(0, 0, 10, 10)->_textsFor("Deutsch")],
        ["Text 0 / 0", "Text 10 / 10"]);
}


sub differentFrames : Test {
    is_deeply([makeTexts(0, 110, 10, 10)->_textsFor("Deutsch")],
        ["Text 10 / 10", "Text 0 / 110"]);
}
