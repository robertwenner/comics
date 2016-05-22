use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub make_comic {
    my ($width) = @_;

    *Comic::_slurp = sub {
        return <<XML;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{
&quot;title&quot;: {
    &quot;English&quot;: &quot;Drinking beer;&quot;
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:groupmode="layer"
     id="layer6"
     inkscape:label="Rahmen"
     sodipodi:insensitive="true">
    <rect
       style="display:inline;fill:none;stroke:#000000;stroke-width:$width;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
       id="rect6486"
       width="234.86922"
       height="178.6805"
       x="0.65975022"
       y="873.02191" />
  </g>
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    return new Comic('whatever');
}


sub width_ok : Test {
    my $comic = make_comic(1.25);
    $comic->_check_frames();
    ok(1);
}


sub width_too_narrow : Test {
    my $comic = make_comic(0.99);
    eval {
        $comic->_check_frames();
    };
    like($@, qr{too narrow}i);
}


sub width_too_wide : Test {
    my $comic = make_comic(1.51);
    eval {
        $comic->_check_frames();
    };
    like($@, qr{too wide}i);
}
