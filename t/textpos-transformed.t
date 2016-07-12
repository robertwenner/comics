use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


my $comic;

sub before : Test(setup) {
    $comic = MockComic::make_comic();
}


sub make_node {
    my ($xml) = @_;
    my $dom = XML::LibXML->load_xml(string => $xml);
    return $dom->documentElement();
}


sub fails_on_bad_attribute : Test {
    eval {
        $comic->_transformed(
            make_node('<text x="1" y="1" transform="matrix(1,2,3,4,5,6)"/>'), "foo");
    };
    like($@, qr/unsupported attribute/i);
}


sub no_transformation : Test {
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


sub multiple_operations : Test {
    eval {
        $comic->_transformed(
            make_node('<text x="1" y="1" transform="scale(1,2) scale(3,4)"/>'), "foo");
    };
    like($@, qr/cannot handle multiple/i);
}
