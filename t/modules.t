use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Comic::Modules;


__PACKAGE__->runtests() unless caller;


sub module_name : Tests {
    is(Comic::Modules::module_name("baz.pm"), "baz");
    is(Comic::Modules::module_name("foo/bar/baz.pm"), "foo::bar::baz");
    is(Comic::Modules::module_name("foo::bar::baz"), "foo::bar::baz");
}


sub module_path : Tests {
    is(Comic::Modules::module_path("foo"), "foo.pm");
    is(Comic::Modules::module_path("foo::bar::baz"), "foo/bar/baz.pm");
    is(Comic::Modules::module_path("foo/bar/baz.pm"), "foo/bar/baz.pm");
}
