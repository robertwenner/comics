use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub make_comic {
    my ($pubDate) = @_;

    return MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken',
        },
        $MockComic::PUBLISHED_WHEN => $pubDate,
    );
}


sub sort_equals : Test {
    my $today = make_comic("2016-04-17");
    ok(Comic::_compare($today, $today) == 0);
}


sub sort_by_published_date : Tests {
    my $today = make_comic("2016-04-17");
    my $yesterday = make_comic("2016-04-16");
    ok(Comic::_compare($today, $yesterday) > 0);
    ok(Comic::_compare($yesterday, $today) < 0);
}


sub sort_by_undefined_published_date : Tests {
    my $today = make_comic("2016-04-17");
    my $oops = make_comic("");
    ok(Comic::_compare($today, $oops) < 0);
    ok(Comic::_compare($oops, $today) > 0);
}


sub sort_array : Test {
    my $jan = make_comic("2016-01-01");
    my $feb = make_comic("2016-02-01");
    my $mar = make_comic("2016-03-01");

    is_deeply(
        [sort Comic::_compare $feb, $mar, $jan],
        [$jan, $feb, $mar]);
}
