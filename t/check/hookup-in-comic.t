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
