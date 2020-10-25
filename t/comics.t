use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Comics;

__PACKAGE__->runtests() unless caller;


sub load_settings : Tests {
    my @loaded;

    no warnings qw/redefine/;
    local *Comics::_exists = sub {
        return 1;
    };
    local *File::Slurp::slurp = sub {
        push @loaded, @_;
        return "{}";
    };
    use warnings;

    my $comics = Comics->new();
    $comics->load_settings("one", "two", "three");

    is_deeply(\@loaded, ["one", "two", "three"]);
}
