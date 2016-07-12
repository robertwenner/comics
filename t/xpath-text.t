use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Comic;

__PACKAGE__->runtests() unless caller;


sub oneElement : Test {
    is('/defNs:svg/defNs:x', Comic::_build_xpath("x"));
}


sub multipleElements : Test {
    is('/defNs:svg/defNs:x', Comic::_build_xpath("x"));
}


sub attribute : Test {
    is('/defNs:svg/defNs:x/defNs:y/defNs:z', Comic::_build_xpath('x', 'y', 'z'));
}
