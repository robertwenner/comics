use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Comic::Check::Weekday;


__PACKAGE__->runtests() unless caller;


my $check;


sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::Weekday->new(5);
}


sub no_weekday_in_ctor : Tests {
    $check = Comic::Check::Weekday->new();
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-03');
    $check->check($comic);
    ok(1);
}


sub bad_weekday_in_ctor : Tests {
    eval {
        Comic::Check::Weekday->new({});
    };
    like($@, qr{bad weekday}i);
    eval {
        Comic::Check::Weekday->new(0);
    };
    like($@, qr{bad weekday}i);
    eval {
        Comic::Check::Weekday->new(8);
    };
    like($@, qr{bad weekday}i);
}


sub good_weekday_in_ctor : Tests {
    foreach my $i (1..7) {
        Comic::Check::Weekday->new($i);
    }
    ok(1);
}


sub no_date : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => undef);
    $check->check($comic);
    ok(1);
}


sub web_comic_scheduled_for_friday_ok : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-03');
    eval {
        $check->check($comic);
    };
    is($@, '');
    is_deeply($comic->{warnings}, []);
}


sub web_comic_scheduled_for_saturday : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-04');
    eval {
        $check->check($comic);
    };
    is($@, '');
    is_deeply($comic->{warnings}, ['Comic::Check::Weekday: Scheduled for Saturday']);
}


sub web_comic_scheduled_for_thursday : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-02');
    eval {
        $check->check($comic);
    };
    is($@, '');
    is_deeply($comic->{warnings}, ['Comic::Check::Weekday: Scheduled for Thursday']);
}


sub multiple_weekdays : Tests {
    $check = Comic::Check::Weekday->new(1, 2, 3);
    #     August 2022
    # Su Mo Tu We Th Fr Sa
    #     1  2  3  4  5  6
    #  7  8  9 10 11 12 13
    # 14 15 16 17 18 19 20
    # 21 22 23 24 25 26 27
    # 28 29 30 31
    foreach my $date ('2022-08-01', '2022-08-02', '2022-08-03') {
        my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => $date);
        $check->check($comic);
        is_deeply($comic->{warnings}, [], 'should not warn');
    }
}
