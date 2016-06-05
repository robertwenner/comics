use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use DateTime;
use Comic;

__PACKAGE__->runtests() unless caller;

sub no_png : Test {
    local *Comic::_exists = sub {
        return 0;
    };
    is(Comic::_up_to_date("comic.svg", "comic.png"), 0);
}


sub svg_older : Test {
    local *Comic::_exists = sub {
        return 1;
    };
    my %mtime = (
        "comic.svg" => 100,
        "comic.png" => 50
    );
    local *Comic::_mtime = sub {
        my ($file) = @_;
        return $mtime{$file};
    };
    is(!1, Comic::_up_to_date("comic.svg", "comic.png"));
}


sub svg_newer : Test {
    local *Comic::_exists = sub {
        return 1;
    };
    my %mtime = (
        "comic.svg" => 100,
        "comic.png" => 200
    );
    local *Comic::_mtime = sub {
        my ($file) = @_;
        return $mtime{$file};
    };
    is(1, Comic::_up_to_date("comic.svg", "comic.png"));
}
