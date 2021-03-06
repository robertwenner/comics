use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use lib 't/check';
use Comic::Settings;
use DummyCheck;

use Comic::Check::Check;
use Comic::Check::Actors;
use Comic::Check::Weekday;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub find_checks : Tests {
    my @modules = Comic::Check::Check::find_all();
    my %modules = map {$_ => 1} @modules;
    is($modules{'Comic/Check/Title.pm'}, 1, 'should include a real check module');
    is($modules{'Comic/Check/Check.pm'}, undef, 'should not include abstract base class');
}


sub check_cached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 1;

    my $check = DummyCheck->new();
    @{$comic->{checks}} = ($check);

    $comic->check();
    is(${$check->{calls}}{'notify'}, 1, 'should have notified about comic');
    is(${$check->{calls}}{'check'}, undef, 'should not have checked cached comic');
}


sub check_uncached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 0;

    my $check = DummyCheck->new();
    @{$comic->{checks}} = ($check);

    $comic->check();
    is(${$check->{calls}}{'notify'}, 1, 'should have notified about comic');
    is(${$check->{calls}}{'check'}, 1, 'should have checked cached comic');
}


sub comic_overrides_main_config_checks_as_object : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Checks": { "use": { "DummyCheck": ["from comic"] } }',
    );
    is(@{$comic->{checks}}, 1, 'should have one check');
    ok(${$comic->{checks}}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[0]->{args}, ["from comic"], 'passed wrong ctor args');
}


sub comic_overrides_main_config_checks_as_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Checks": { "use": [ "DummyCheck" ] }',
    );
    is(@{$comic->{checks}}, 1, 'should have one check');
    ok(${$comic->{checks}}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[0]->{args}, [], 'passed wrong ctor args');
}


sub comic_adds_main_config_checks_as_object : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => "biercomics.de",
                $MockComic::ENGLISH => "beercomics.com",
            },
            $Comic::Settings::CHECKS => [ Comic::Check::Actors->new() ],
        },
        $MockComic::JSON => '"Checks": { "add": { "DummyCheck": ["from comic"] } }',
    );
    is(@{$comic->{checks}}, 2, 'should have two checks');
    ok(${$comic->{checks}}[0]->isa("Comic::Check::Actors"), 'modified existing check');
    ok(${$comic->{checks}}[1]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[1]->{args}, ["from comic"], 'passed wrong ctor args');
}


sub comic_adds_to_main_config_as_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            $Comic::Settings::CHECKS => [ Comic::Check::Actors->new() ],
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => "biercomics.de",
                $MockComic::ENGLISH => "beercomics.com",
            },
        },
        $MockComic::JSON => '"Checks": { "add": [ "DummyCheck" ] }',
    );
    is(@{$comic->{checks}}, 2, 'should have two checks');
    ok(${$comic->{checks}}[0]->isa("Comic::Check::Actors"), 'modified existing check');
    ok(${$comic->{checks}}[1]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[1]->{args}, [], 'passed wrong ctor args');
}


sub comic_add_same_type_check_replaces_original : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            $Comic::Settings::CHECKS => [ Comic::Check::Weekday->new(1) ],
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => "biercomics.de",
                $MockComic::ENGLISH => "beercomics.com",
            },
        },
        $MockComic::JSON => '"Checks": { "add": { "Comic::Check::Weekday": [2] } }',
    );
    is(@{$comic->{checks}}, 1, 'should have one check');
    ok(${$comic->{checks}}[0]->isa("Comic::Check::Weekday"), 'wrong kind of check');
    is_deeply(${$comic->{checks}}[0]->{weekday}, 2, 'still has old check');
}


sub comic_remove_from_config : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            $Comic::Settings::CHECKS => [ Comic::Check::Weekday->new(1) ],
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => "biercomics.de",
                $MockComic::ENGLISH => "beercomics.com",
            },
        },
        $MockComic::JSON => '"Checks": { "remove": [ "Comic/Check/Weekday.pm" ] }',
    );
    is(@{$comic->{checks}}, 0, 'should have no checks');
}


sub comic_remove_from_config_as_hash_gets_nice_error_message : Tests {
    eval {
        MockComic::make_comic(
            $MockComic::JSON => '"Checks": { "remove": { "DummyCheck": 1 } }',
        );
    };
    like($@, qr{must pass an array to "remove"}i);
}


sub comic_check_unknown_command : Tests {
    eval {
        MockComic::make_comic(
            $MockComic::JSON => '"Checks": { "include": { "DummyCheck": 1 } }',
        );
    };
    like($@, qr{unknown check}i);
    like($@, qr{\binclude\b}i);
    like($@, qr{\buse\b}i);
    like($@, qr{\badd\b}i);
    like($@, qr{\bremove\b}i);
}
