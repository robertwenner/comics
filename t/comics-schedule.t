use strict;
use warnings;
use DateTime::Format::ISO8601;

use base 'Test::Class';
use Test::More;

use Comics;

use lib 't';
use MockComic;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub croaks_if_no_weekday_configuration : Tests {
    my $comics = Comics->new();

    eval {
        $comics->next_publish_day();
    };
    like($@, qr{Comic::Check::Weekday}, 'should mention setting');
    like($@, qr{not found}, 'should say what is wrong');
}


sub croaks_if_weekday_configuration_is_empty : Tests {
    my $comics = Comics->new();
    $comics->{settings}->load_str('{"Checks": { "Comic::Check::Weekday": [] } }');

    eval {
        $comics->next_publish_day();
    };
    like($@, qr{Comic::Check::Weekday}, 'should mention setting');
    like($@, qr{\bempty\b}, 'should say what is wrong');
}


sub croaks_if_next_publish_day_is_neither_array_nor_scalar : Tests {
    my $comics = Comics->new();
    $comics->{settings}->load_str('{ "Checks": { "Comic::Check::Weekday": {} } }');

    eval {
        $comics->next_publish_day();
    };
    like($@, qr{Comic::Check::Weekday}, 'should mention setting');
    like($@, qr{\bscalar\b}, 'should say it accepts a scalar');
    like($@, qr{\barray\b}, 'should say it accepts an array');
}


sub schedule_for_one_day : Tests {
    #     August 2022
    # Su Mo Tu We Th Fr Sa
    #    1  2  3  4  5  6
    #  7  8  9 10 11 12 13
    # 14 15 16 17 18 19 20
    # 21 22 23 24 25 26 27
    # 28 29 30 31
    my %today_to_next_friday = (
        '2022-08-01' => '2022-08-05',
        '2022-08-02' => '2022-08-05',
        '2022-08-03' => '2022-08-05',
        '2022-08-04' => '2022-08-05',
        '2022-08-05' => '2022-08-05',
        '2022-08-06' => '2022-08-12',
        '2022-08-07' => '2022-08-12',
        '2022-08-08' => '2022-08-12',
    );
    my $comics = Comics->new();
    $comics->{settings}->load_str('{ "Checks": { "Comic::Check::Weekday": 5 } }'); # Fri

    foreach my $today (keys %today_to_next_friday) {
        MockComic::fake_now(DateTime::Format::ISO8601->parse_datetime("${today}T00:00:00"));

        my $scheduled_for = $comics->next_publish_day();

        is($scheduled_for, $today_to_next_friday{$today}, "Wrong publishing day from $today");
    }
}


sub schedule_for_multiple_days : Tests {
    #     August 2022
    # Su Mo Tu We Th Fr Sa
    #     1  2  3  4  5  6
    #  7  8  9 10 11 12 13
    # 14 15 16 17 18 19 20
    # 21 22 23 24 25 26 27
    # 28 29 30 31
    my %today_to_next_friday = (
        '2022-08-01' => '2022-08-01',
        '2022-08-02' => '2022-08-05',
        '2022-08-03' => '2022-08-05',
        '2022-08-04' => '2022-08-05',
        '2022-08-05' => '2022-08-05',
        '2022-08-06' => '2022-08-08',
        '2022-08-07' => '2022-08-08',
        '2022-08-08' => '2022-08-08',
        '2022-08-09' => '2022-08-12',
    );
    my $comics = Comics->new();
    $comics->{settings}->load_str('{ "Checks": { "Comic::Check::Weekday": [1, 5] } }'); # Mon, Fri

    foreach my $today (keys %today_to_next_friday) {
        MockComic::fake_now(DateTime::Format::ISO8601->parse_datetime("${today}T00:00:00"));

        my $scheduled_for = $comics->next_publish_day();

        is($scheduled_for, $today_to_next_friday{$today}, "Wrong publishing day from $today");
    }
}


sub schedule_skips_dates_taken : Tests {
    #     August 2022
    # Su Mo Tu We Th Fr Sa
    #     1  2  3  4  5  6
    #  7  8  9 10 11 12 13
    # 14 15 16 17 18 19 20
    # 21 22 23 24 25 26 27
    # 28 29 30 31
    MockComic::fake_now(DateTime::Format::ISO8601->parse_datetime("2022-08-03T00:00:00")); # Wed
    my $comics = Comics->new();
    push @{$comics->{comics}},
        MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2022-08-05'),
        MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2022-08-12'),
        MockComic::make_comic($MockComic::PUBLISHED_WHEN => ''),
        MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2022-08-26');

    $comics->{settings}->load_str('{ "Checks": { "Comic::Check::Weekday": [5] } }'); # Fri

    my $scheduled_for = $comics->next_publish_day();

    is($scheduled_for, '2022-08-19', "Wrong publishing day");
}
