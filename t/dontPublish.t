use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub makeComic {
    my ($json) = @_;

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
        <dc:description>$json</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    return Comic->new('whatever');
}


sub inJsonHash : Test {
    my $comic = makeComic(<<JSON);
{&quot;title&quot;: {
    &quot;English&quot;: &quot;DONT_PUBLISH fix me&quot;
}}
JSON
    eval {
        $comic->_checkDontPublish();
    };
    like($@, qr{In JSON > title > English: DONT_PUBLISH fix me});
}


sub inJsonArray : Test {
    my $comic = makeComic(<<JSON);
{&quot;who&quot;: {
    &quot;English&quot;: [
        &quot;one&quot;, &quot;two&quot;, &quot;three DONT_PUBLISH&quot;, &quot;four&quot;
   ]
}}
JSON
    eval {
        $comic->_checkDontPublish();
    };
    like($@, qr{In JSON > who > English\[3\]: three DONT_PUBLISH});
}


sub inJsonTopLevelElement : Test {
    my $comic = makeComic(<<JSON);
{&quot;who&quot;: &quot;DONT_PUBLISH top level&quot;}
JSON
    eval {
        $comic->_checkDontPublish();
    };
    like($@, qr{In JSON > who: DONT_PUBLISH top level});
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
        $comic->_checkDontPublish("English");
    };
    like($@, qr{In layer Deutsch: DONT_PUBLISH oops});
}
