use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use DateTime;
use Comic;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub comic_output_file_does_not_exist : Tests {
    local *Comic::_mtime = sub {
        my ($file) = @_;
        if ($file =~ m{\.svg$}) {
            return 12345;
        }
        return undef;
    };
    my $comic = MockComic::make_comic();

    is($comic->up_to_date("comic.png"), 0);
}


sub comic_svg_newer : Tests {
    my %mtime = (
        "some_comic.svg" => 100,
        "some_comic.png" => 50
    );
    local *Comic::_mtime = sub {
        my ($file) = @_;
        return $mtime{$file};
    };
    my $comic = MockComic::make_comic();

    is($comic->up_to_date("some_comic.png"), 0);
}


sub comic_svg_older : Tests {
    my %mtime = (
        "some_comic.svg" => 100,
        "comic.png" => 200
    );
    local *Comic::_mtime = sub {
        my ($file) = @_;
        return $mtime{$file};
    };
    my $comic = MockComic::make_comic();

    ok($comic->up_to_date("comic.png"));
}


sub comic_caches_mtime : Tests {
    my @mtime_calls;
    local *Comic::_mtime = sub {
        my ($file) = @_;
        push @mtime_calls, $file;
        return 123;
    };
    my $comic = MockComic::make_comic();

    $comic->up_to_date("comic.png");
    $comic->up_to_date("comic.png");
    is_deeply(\@mtime_calls, ['some_comic.svg', 'comic.png']);
}
