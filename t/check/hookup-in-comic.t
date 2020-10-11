use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use lib 't/check';
use DummyCheck;

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


sub uses_all_checks_if_configuration_file_doesnt_exist : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, undef);
    my $comic = MockComic::make_comic();
    ok(@Comic::checks > 0, 'should have checks');
}


sub uses_all_checks_if_no_checks_config_section_exists : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{}');
    my $comic = MockComic::make_comic();
    ok(@Comic::checks > 0, 'should have checks');
}


sub uses_no_checks_if_checks_config_section_is_empty : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": {} }');
    my $comic = MockComic::make_comic();
    is(@Comic::checks, 0, 'should not have checks');
}


sub passes_args_to_configured_check_from_list : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "DummyCheck.pm": [1, 2, 3] } }');
    my $comic = MockComic::make_comic();
    is(@Comic::checks, 1, 'should have one check');
    ok($Comic::checks[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($Comic::checks[0]->{args}, [1, 2, 3], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_from_object : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "DummyCheck.pm": {"a": 1} } }');
    my $comic = MockComic::make_comic();
    is(@Comic::checks, 1, 'should have one check');
    ok($Comic::checks[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($Comic::checks[0]->{args}, ["a", 1], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_from_scalar_value : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "DummyCheck.pm": "a" } }');
    my $comic = MockComic::make_comic();
    is(@Comic::checks, 1, 'should have one check');
    ok($Comic::checks[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($Comic::checks[0]->{args}, ["a"], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_null : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "DummyCheck.pm": null } }');
    MockComic::make_comic();
    is(@Comic::checks, 1, 'should have one check');
    ok($Comic::checks[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($Comic::checks[0]->{args}, [], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_boolean : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "DummyCheck.pm": true } }');
    eval {
        MockComic::make_comic();
    };
    like($@, qr{cannot handle}i);
}


sub uses_configured_check_path : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Actors.pm": [] } }');
    my $comic = MockComic::make_comic();
    is(@Comic::checks, 1, 'should have one check');
    ok($Comic::checks[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_check_module_name : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic::Check::Actors": [] } }');
    my $comic = MockComic::make_comic();
    is(@Comic::checks, 1, 'should have one check');
    ok($Comic::checks[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_check_without_extension : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Actors": [] } }');
    my $comic = MockComic::make_comic();
    is(@Comic::checks, 1, 'should have one check');
    ok($Comic::checks[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub croaks_on_unknown_configured_check : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "NoSuchCheck": [] } }');
    eval {
        MockComic::make_comic();
    };
    like($@, qr{Can't locate NoSuchCheck});
}


sub croaks_on_wrong_config_syntax_checks_not_object : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": "DummyCheck" }');
    eval {
        MockComic::make_comic();
    };
    like($@, qr{must be a json object}i);
}


sub check_cycle_for_cached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 1;

    my $check = DummyCheck->new();
    @{$comic->{checks}} = ($check);
    @Comic::checks = ($check);

    $comic->check();

    is(${$check->{calls}}{'notify'}, 1, 'should have notified about comic');
    is(${$check->{calls}}{'check'}, undef, 'should not have checked cached comic');
    is(${$check->{calls}}{'final_check'}, undef, 'should not yet have done final check');

    $comic->_final_checks();
    is(${$check->{calls}}{'final_check'}, 1, 'should have done final check');
}


sub check_cycle_for_uncached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 0;

    my $check = DummyCheck->new();
    @{$comic->{checks}} = ($check);
    @Comic::checks = ($check);

    $comic->check();

    is(${$check->{calls}}{'notify'}, 1, 'should have notified about comic');
    is(${$check->{calls}}{'check'}, 1, 'should have checked cached comic');
    is(${$check->{calls}}{'final_check'}, undef, 'should not yet have done final check');

    $comic->_final_checks();
    is(${$check->{calls}}{'final_check'}, 1, 'should have done final check');
}


sub comic_overrides_main_config_checks_as_object : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Actors.pm": [] } }');
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Check": { "use": { "DummyCheck": ["from comic"] } }',
    );
    is(@{$comic->{checks}}, 1, 'should have one check');
    ok(${$comic->{checks}}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[0]->{args}, ["from comic"], 'passed wrong ctor args');

    is(@{Comic::checks}, 1, 'should still have one check for all comics');
    ok(${Comic::checks}[0]->isa("Comic::Check::Actors"), 'messed up check for all comics');
}


sub comic_overrides_main_config_checks_as_array : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Actors.pm": [] } }');
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Check": { "use": [ "DummyCheck" ] }',
    );
    is(@{$comic->{checks}}, 1, 'should have one check');
    ok(${$comic->{checks}}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[0]->{args}, [], 'passed wrong ctor args');

    is(@{Comic::checks}, 1, 'should still have one check for all comics');
    ok(${Comic::checks}[0]->isa("Comic::Check::Actors"), 'messed up check for all comics');
}


sub comic_adds_main_config_checks_as_object : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Actors.pm": [] } }');
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Check": { "add": { "DummyCheck": ["from comic"] } }',
    );
    is(@{$comic->{checks}}, 2, 'should have two checks');
    ok(${$comic->{checks}}[0]->isa("Comic::Check::Actors"), 'modified existing check');
    ok(${$comic->{checks}}[1]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[1]->{args}, ["from comic"], 'passed wrong ctor args');

    is(@{Comic::checks}, 1, 'should still have one check for all comics');
    ok(${Comic::checks}[0]->isa("Comic::Check::Actors"), 'messed up check for all comics');
}


sub comic_adds_to_main_config_as_array : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Actors.pm": [] } }');
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Check": { "add": [ "DummyCheck" ] }',
    );
    is(@{$comic->{checks}}, 2, 'should have two checks');
    ok(${$comic->{checks}}[0]->isa("Comic::Check::Actors"), 'modified existing check');
    ok(${$comic->{checks}}[1]->isa("DummyCheck"), 'created wrong check');
    is_deeply(${$comic->{checks}}[1]->{args}, [], 'passed wrong ctor args');

    is(@{Comic::checks}, 1, 'should still have one check for all comics');
    ok(${Comic::checks}[0]->isa("Comic::Check::Actors"), 'messed up check for all comics');
}


sub comic_add_same_type_check_replaces_original : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Weekday.pm": [1] } }');
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Check": { "add": { "Comic::Check::Weekday": [2] } }',
    );
    is(@{$comic->{checks}}, 1, 'should have one check');
    ok(${$comic->{checks}}[0]->isa("Comic::Check::Weekday"), 'wrong kind of check');
    is_deeply(${$comic->{checks}}[0]->{weekday}, 2, 'still has old check');

    is(@{Comic::checks}, 1, 'should still have one check for all comics');
    ok(${Comic::checks}[0]->isa("Comic::Check::Weekday"), 'messed up check for all comics');
    is_deeply(${Comic::checks}[0]->{weekday}, 1, 'messed up weekday for all comics');
}


sub comic_remove_from_config : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "Comic/Check/Weekday.pm": [1] } }');
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"Check": { "remove": [ "Comic/Check/Weekday.pm" ] }',
    );
    is(@{$comic->{checks}}, 0, 'should have no checks');

    is(@{Comic::checks}, 1, 'should still have one check for all comics');
    ok(${Comic::checks}[0]->isa("Comic::Check::Weekday"), 'messed up check for all comics');
    is_deeply(${Comic::checks}[0]->{weekday}, 1, 'messed up weekday for all comics');
}


sub comic_remove_from_config_as_hash_gets_nice_error_message : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "DummyCheck": [1] } }');
    eval {
        MockComic::make_comic(
            $MockComic::JSON => '"Check": { "remove": { "DummyCheck": 1 } }',
        );
    };
    like($@, qr{must pass an array to "remove"}i);
}


sub comic_check_unknown_command : Tests {
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{ "Check": { "DummyCheck": [1] } }');
    eval {
        MockComic::make_comic(
            $MockComic::JSON => '"Check": { "include": { "DummyCheck": 1 } }',
        );
    };
    like($@, qr{unknown check}i);
    like($@, qr{\binclude\b}i);
    like($@, qr{\buse\b}i);
    like($@, qr{\badd\b}i);
    like($@, qr{\bremove\b}i);
}
