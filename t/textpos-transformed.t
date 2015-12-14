use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub makeNode {
    my ($xml) = @_;
    my $dom = XML::LibXML->load_xml(string => $xml);
    return $dom->documentElement();
}


sub failsOnBadAttribute : Test {
    eval {
        Comic::_transformed(
            makeNode('<text x="1" y="1" transform="matrix(1,2,3,4,5,6)"/>'), "foo");
    };
    like($@, qr/unsupported attribute/i);
}


sub noTransformation : Test {
    is(Comic::_transformed(
        makeNode('<text x="329.6062" y="-1456.9886"/>'), "x"), 
    329.6062);
}


sub matrix : Test {
    is(Comic::_transformed(makeNode(
        '<text x="5" y="7" transform="matrix(1,2,3,4,5,6)"/>'), "x"),
    1 * 5 + 3 * 7);
}


sub scale : Test {
    is(Comic::_transformed(makeNode(
        '<text x="5" y="7" transform="scale(7,9)"/>'), "x"),
    5 * 7);
}


sub multipleOperations : Test {
    eval {
        Comic::_transformed(
            makeNode('<text x="1" y="1" transform="scale(1,2) scale(3,4)"/>'), "foo");
    };
    like($@, qr/cannot handle multiple/i);
}
