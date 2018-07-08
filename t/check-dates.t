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


sub no_dates : Test {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => undef);
    $comic->_check_date();
    ok(1);
}


sub no_collision : Test {
    MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-01');
    MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-02');
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-03');
    $comic->_check_date();
    ok(1);
}


sub collision : Test {
    MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::IN_FILE => 'one.svg');
    MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-02');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::IN_FILE => 'three.svg');
    eval {
        $comic->_check_date();
    };
    like($@, qr{three\.svg : duplicated date .+ one\.svg});
}


sub collision_ignores_whitespace : Test {
    MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01 ',
        $MockComic::IN_FILE => 'one.svg');
    MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-02');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => ' 2016-01-01',
        $MockComic::IN_FILE => 'three.svg');
    eval {
        $comic->_check_date();
    };
    like($@, qr{three\.svg : duplicated date .+ one\.svg});
}


sub no_collision_different_languages : Test {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'not funny in German',
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'auf Englisch nicht lustig',
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01');
    eval {
        $comic->_check_date();
    };
    is($@, '');
}


sub no_collision_published_elsewhere : Tests {
    MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'one.svg');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::PUBLISHED_WHERE => 'offline',
        $MockComic::IN_FILE => 'other.svg');
    eval {
        $comic->_check_date();
    };
    is($@, '');
}


sub web_comic_scheduled_for_saturday : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-04');
    eval {
        $comic->_check_date();
    };
    is($@, '');
    is_deeply($comic->{warnings}, ['scheduled for Saturday']);
}


sub web_comic_scheduled_for_thursday : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-02');
    eval {
        $comic->_check_date();
    };
    is($@, '');
    is_deeply($comic->{warnings}, ['scheduled for Thursday']);
}


sub web_comic_scheduled_for_today_thursday : Tests {
    MockComic::fake_now(DateTime->new(year => 3000, month => 1, day => 02));
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3000-01-02');
    eval {
        $comic->_check_date();
    };
    # Need to check an error, not just a warning, like in the other tests, cause
    # the comic is already (being) published.
    like($@, qr/scheduled for Thursday/);
}
