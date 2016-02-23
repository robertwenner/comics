use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub inJson : Test {
    *Comic::_slurp = sub {
        return <<XML;
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>
{&quot;title&quot;: {
    &quot;en&quot;: &quot;DONT_PUBLISH fix me&quot;
}}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    my $comic = Comic->new('whatever');

    eval {
        $comic->_checkDontPublish();
    };
    like($@, qr{In JSON title > en: DONT_PUBLISH fix me});
}


sub inText : Test {
    *Comic::_slurp = sub {
        return <<XML;
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g inkscape:groupmode="layer" inkscape:label="Deutsch" style="display:inline">
    <text>
        <tspan>DONT_PUBLISH oops</tspan>
        <tspan>other text</tspan>
    </text>
  </g>
</svg>
XML
    };
    my $comic = Comic->new('whatever');
    
    eval {
        $comic->_checkDontPublish("en");
    };
    like($@, qr{In layer Deutsch: DONT_PUBLISH oops});
}
