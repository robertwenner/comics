use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::Deep;

use File::Basename;
BEGIN {
    push @INC, dirname(__FILE__) . "/..";
}
use Comic;

__PACKAGE__->runtests() unless caller;


sub oneElement : Test {
    is('/defNs:svg/defNs:x', Comic::_buildXpath("x"));
}


sub multipleElements : Test {
    is('/defNs:svg/defNs:x', Comic::_buildXpath("x"));
}


sub attribute : Test {
    is('/defNs:svg/defNs:x/defNs:y/defNs:z', Comic::_buildXpath('x', 'y', 'z'));
}
