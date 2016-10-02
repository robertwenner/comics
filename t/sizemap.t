use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub make_comic {
    my ($width, $height) = @_;

    my $comic = MockComic::make_comic();
    $comic->{height} = $height;
    $comic->{width} = $width;
    return $comic;
}


sub sorting : Tests {
    my $a = make_comic(10, 100);
    my $b = make_comic(20, 90);
    my $c = make_comic(30, 80);

    is_deeply([$c, $b, $a], [sort Comic::_by_height ($b, $a, $c)]);
    is_deeply([$a, $b, $c], [sort Comic::_by_width ($b, $a, $c)]);
}


sub aggregate_none : Tests {
    my %aggregated = Comic::_aggregate_comic_sizes('Deutsch', 'English');
    is_deeply(\%aggregated, {
        height => {
            min => 9999999,
            max => 0,
            avg => 'n/a',
            cnt => 0,
       },
        width => {
            min => 9999999,
            max => 0,
            avg => 'n/a',
            cnt => 0,
       },
    });
}


sub aggregate_one : Tests {
    make_comic(100, 300);
    my %aggregated = Comic::_aggregate_comic_sizes('Deutsch', 'English');
    is_deeply(\%aggregated, {
        height => {
            min => 300,
            max => 300,
            avg => 300,
            cnt => 1,
       },
        width => {
            min => 100,
            max => 100,
            avg => 100,
            cnt => 1,
       },
    });
}


sub aggregate_many : Tests {
    make_comic(100, 500);
    make_comic(200, 600);
    make_comic(300, 400);
    my %aggregated = Comic::_aggregate_comic_sizes('Deutsch', 'English');
    is_deeply(\%aggregated, {
        height => {
            min => 400,
            max => 600,
            avg => 500,
            cnt => 3,
       },
        width => {
            min => 100,
            max => 300,
            avg => 200,
            cnt => 3,
        },
    });
}



sub sort_styles : Tests {
    is(Comic::_sort_styles(''), '');
    is(Comic::_sort_styles(
        '<rect style="stroke: green; fill-opacity: 0; stroke-width: 3"/>'), 
        '<rect style="fill-opacity: 0; stroke-width: 3; stroke: green"/>' . "\n");
    is(Comic::_sort_styles(
        '<rect style="stroke: green; fill-opacity: 0; stroke-width: 3" width="180" x="0" y="0"/>' . "\n" .
        '<rect style="stroke: green; fill-opacity: 0; stroke-width: 3" width="180" x="0" y="0"/>' . "\n" .
        '<rect style="stroke: green; fill-opacity: 0; stroke-width: 3" width="180" x="0" y="0"/>' . "\n"),

        '<rect style="fill-opacity: 0; stroke-width: 3; stroke: green" width="180" x="0" y="0"/>' . "\n" .
        '<rect style="fill-opacity: 0; stroke-width: 3; stroke: green" width="180" x="0" y="0"/>' . "\n" .
        '<rect style="fill-opacity: 0; stroke-width: 3; stroke: green" width="180" x="0" y="0"/>' . "\n");
}