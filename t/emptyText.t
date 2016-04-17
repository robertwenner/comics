use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub makeComic {
    *Comic::_slurp = sub {
        return <<XML;
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   version="1.1"
   inkscape:version="0.91 r">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="MetaDeutsch"
     style="display:inline">
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:125%;font-family:RW5;-inkscape-font-specification:'RW Medium';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       id="text16220"
       sodipodi:linespacing="125%"><tspan
         sodipodi:role="line"
         id="tspan16222"/></text>
    }
  </g>
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    return Comic->new('whatever');
}


sub emptyTextFound : Test {
    my $comic = makeComic();
    eval {
        $comic->_textsFor("Deutsch");
    };
    like($@, qr{Empty text in MetaDeutsch with ID text16220}i);
}


sub emptyTextOtherLanguageIgnored : Test {
    my $comic = makeComic();
    eval {
        $comic->_textsFor("English");
    };
    is($@, '');
}
