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


sub web_comic_scheduled_for_today_thursday : Tests {
    MockComic::fake_now(DateTime->new(year => 3000, month => 1, day => 2));
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-02');
    eval {
        $check->check($comic);
    };
    # Need to check an error, not just a warning, like in the other tests, cause
    # the comic is already (being) published.
    like($@, qr/scheduled for Thursday/i);
}
