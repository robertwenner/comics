use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use DateTime;
use Comic;

__PACKAGE__->runtests() unless caller;


sub no_png : Tests {
    local *Comic::_exists = sub {
        return 0;
    };
    my $comic = Comic->new({}, []);
    $comic->{srcFile} = 'comic.svg';

    is($comic->up_to_date("comic.png"), 0);
}


sub svg_newer : Tests {
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
    my $comic = Comic->new({}, []);
    $comic->{srcFile} = 'comic.svg';

    is($comic->up_to_date("comic.png"), 0);
}


sub svg_older : Tests {
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
    my $comic = Comic->new({}, []);
    $comic->{srcFile} = 'comic.svg';

    ok($comic->up_to_date("comic.png"));
}
