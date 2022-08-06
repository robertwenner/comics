use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::Output;
use lib 't';
use MockComic;
use Comic::Settings;
use lib 't/check';
use DummyCheck;
use lib 't/out';
use DummyGenerator;

use Comics;
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


sub check_comic : Tests {
    my $comic = MockComic::make_comic();

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
        },
        $MockComic::CHECKS => [ Comic::Check::Actors->new() ],
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
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => "biercomics.de",
                $MockComic::ENGLISH => "beercomics.com",
            },
        },
        $MockComic::CHECKS => [ Comic::Check::Actors->new() ],
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
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => "biercomics.de",
                $MockComic::ENGLISH => "beercomics.com",
            },
        },
        $MockComic::CHECKS => [ Comic::Check::Weekday->new(1) ],
        $MockComic::JSON => '"Checks": { "add": { "Comic::Check::Weekday": [2] } }',
    );
    is(@{$comic->{checks}}, 1, 'should have one check');
    ok(${$comic->{checks}}[0]->isa("Comic::Check::Weekday"), 'wrong kind of check');
    is_deeply(${$comic->{checks}}[0]->{weekday}, [2], 'still has old check');
}


sub comic_remove_from_config : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => "biercomics.de",
                $MockComic::ENGLISH => "beercomics.com",
            },
        },
        $MockComic::CHECKS => [ Comic::Check::Weekday->new(1) ],
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


sub runs_global_final_checks : Tests {
    my $comics = Comics->new();
    my $check = DummyCheck->new();
    push @{$comics->{checks}}, $check;
    $comics->run_final_checks();
    is(1, $check->{calls}{"final_check"});
}


sub runs_per_comic_final_checks : Tests {
    my $comics = Comics->new();
    my $comic = MockComic::make_comic();
    my $check = DummyCheck->new();
    push @{$comic->{checks}}, $check;
    push @{$comics->{comics}}, $comic;

    $comics->run_final_checks();
    is(1, $check->{calls}{"final_check"});
}


sub runs_each_final_check_only_once : Tests {
    my $comics = Comics->new();
    my $comic = MockComic::make_comic();
    my $global_check = DummyCheck->new();
    my $local_check = DummyCheck->new();

    push @{$comic->{checks}}, $global_check, $local_check, $local_check;
    push @{$comics->{checks}}, $global_check, $global_check;
    push @{$comics->{comics}}, $comic;

    $comics->run_final_checks();
    is(1, $global_check->{calls}{"final_check"}, 'should have called global only once');
    is(1, $local_check->{calls}{"final_check"}, 'should have called local only once');
}


sub run_all_checks_runs_only_checks_for_comic : Tests {
    my $comics = Comics->new();
    my $global_check = DummyCheck->new();
    push @{$comics->{checks}}, $global_check;
    my $dummy_generator = DummyGenerator->new();
    push @{$comics->{generators}}, $dummy_generator;

    my $called_comic_check = 0;
    no warnings qw/redefine/;
    local *Comic::check = sub {
        $called_comic_check++;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "drink beer",
        },
    );
    push @{$comics->{comics}}, $comic;

    $comics->run_all_checks();
    is($global_check->{calls}{"final_check"}, undef, 'should not have called global');
    is($called_comic_check, 1, 'should have called Comic::check');
}


sub run_all_checks_skips_up_to_date_comic : Tests {
    my $comics = Comics->new();
    my $global_check = DummyCheck->new();
    push @{$comics->{checks}}, $global_check;
    my $dummy_generator = DummyGenerator->new();
    $dummy_generator->{up_to_date} = 0;
    push @{$comics->{generators}}, $dummy_generator;

    my $called_comic_check = 0;
    no warnings qw/redefine/;
    local *Comic::check = sub {
        $called_comic_check++;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "drink beer",
        },
    );
    push @{$comics->{comics}}, $comic;

    $comics->run_all_checks();
    is($called_comic_check, 1, 'should have called Comic::check');

    $dummy_generator->{up_to_date} = 1;
    $comics->run_all_checks();
    is($called_comic_check, 1, 'should not have called Comic::check again');
}


sub prints_warnings_from_unpublished_comic : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => undef,
    );
    my $check = DummyCheck->new("problem from check");
    push @{$comic->{checks}}, $check;

    stdout_like {
        $comic->check();
    } qr{1 problem}i;
}


sub collect_warnings_from_one_check_published : Tests {
    my $comic = MockComic::make_comic();
    my $check = DummyCheck->new("problem from check");
    push @{$comic->{checks}}, $check;

    eval {
        $comic->check();
    };
    like($@, qr{1 problem}i);
    is_deeply($comic->{warnings}, ["problem from check"]);
}


sub collect_warnings_from_all_checks : Tests {
    my $comic = MockComic::make_comic();
    for (my $i = 0; $i < 3; $i++) {
        my $check = DummyCheck->new("problem from check $i");
        push @{$comic->{checks}}, $check;
    }

    eval {
        $comic->check();
    };
    like($@, qr{3 problems}i);
    is_deeply($comic->{warnings}, ["problem from check 0", "problem from check 1", "problem from check 2"]);
}
