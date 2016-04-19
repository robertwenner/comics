use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;

sub before : Test(setup) {
    *Comic::_slurp = sub {
        my $xml = <<"XML";
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
        return $xml;
    };
    local *Comic::_mtime = sub {
        return 0;
    };
    $comic = Comic->new('whatever');
}


sub make_node {
    my ($xml) = @_;
    my $dom = XML::LibXML->load_xml(string => $xml);
    return $dom->documentElement();
}


sub failsOnBadAttribute : Test {
    eval {
        $comic->_transformed(
            make_node('<text x="1" y="1" transform="matrix(1,2,3,4,5,6)"/>'), "foo");
    };
    like($@, qr/unsupported attribute/i);
}


sub noTransformation : Test {
    is($comic->_transformed(
        make_node('<text x="329.6062" y="-1456.9886"/>'), "x"), 
    329.6062);
}


sub matrix : Test {
    is($comic->_transformed(make_node(
        '<text x="5" y="7" transform="matrix(1,2,3,4,5,6)"/>'), "x"),
    1 * 5 + 3 * 7);
}


sub scale : Test {
    is($comic->_transformed(make_node(
        '<text x="5" y="7" transform="scale(7,9)"/>'), "x"),
    5 * 7);
}


sub multipleOperations : Test {
    eval {
        $comic->_transformed(
            make_node('<text x="1" y="1" transform="scale(1,2) scale(3,4)"/>'), "foo");
    };
    like($@, qr/cannot handle multiple/i);
}
