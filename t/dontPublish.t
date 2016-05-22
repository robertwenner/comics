use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub make_comic {
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


sub in_json_hash : Test {
    my $comic = make_comic(<<JSON);
{&quot;title&quot;: {
    &quot;English&quot;: &quot;DONT_PUBLISH fix me&quot;
}}
JSON
    eval {
        $comic->_check_dont_publish();
    };
    like($@, qr{in JSON > title > English: DONT_PUBLISH fix me}i);
}


sub in_json_array : Test {
    my $comic = make_comic(<<JSON);
{&quot;who&quot;: {
    &quot;English&quot;: [
        &quot;one&quot;, &quot;two&quot;, &quot;three DONT_PUBLISH&quot;, &quot;four&quot;
   ]
}}
JSON
    eval {
        $comic->_check_dont_publish();
    };
    like($@, qr{In JSON > who > English\[3\]: three DONT_PUBLISH}i);
}


sub in_json_top_level_element : Test {
    my $comic = make_comic(<<JSON);
{&quot;who&quot;: &quot;DONT_PUBLISH top level&quot;}
JSON
    eval {
        $comic->_check_dont_publish();
    };
    like($@, qr{In JSON > who: DONT_PUBLISH top level}i);
}


sub in_text : Test {
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
        $comic->_check_dont_publish("English");
    };
    like($@, qr{In layer Deutsch: DONT_PUBLISH oops}i);
}
