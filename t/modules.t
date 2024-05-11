use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::Output;
use lib 't';
use MockComic;
use lib 't/check';

use Comics;
use Comic::Modules;

__PACKAGE__->runtests() unless caller;

my $comics;


sub set_up : Test(setup) {
    MockComic::set_up();
    $comics = Comics->new();
}


sub module_name : Tests {
    is(Comic::Modules::module_name("baz.pm"), "baz");
    is(Comic::Modules::module_name("foo/bar/baz.pm"), "foo::bar::baz");
    is(Comic::Modules::module_name("foo::bar::baz"), "foo::bar::baz");
}


sub module_path : Tests {
    is(Comic::Modules::module_path("foo"), "foo.pm");
    is(Comic::Modules::module_path("foo::bar::baz"), "foo/bar/baz.pm");
    is(Comic::Modules::module_path("foo/bar/baz.pm"), "foo/bar/baz.pm");
}


sub loads_config_file : Tests {
    MockComic::fake_file("config.json", '{"foo": "bar"}');

    $comics->load_settings("config.json");
    my $cloned = $comics->{settings}->clone();
    is("bar", $cloned->{'foo'}, 'should have loaded settings');
}


sub passes_args_to_configured_module_from_list : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "DummyCheck.pm": [1, 2, 3] } }');
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, [1, 2, 3], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_from_object : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "DummyCheck.pm": {"a": 1} } }');
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, ["a", 1], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_from_scalar_value : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "DummyCheck.pm": "a" } }');
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, ["a"], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_null : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "DummyCheck.pm": null } }');
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, [], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_boolean : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "DummyCheck.pm": true } }');
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{cannot handle}i);
}


sub uses_configured_module_path : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "Comic/Check/Actors.pm": [] } }');
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_module_name : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "Comic::Check::Actors": [] } }');
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_module_without_extension : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "Comic/Check/Actors": [] } }');
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub croaks_on_unknown_configured_path : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "NoSuchCheck.pm": [] } }');
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{Can't locate NoSuchCheck\.pm});
}


sub croaks_on_unknown_configured_module : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "No::Such::Check": [] } }');
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{Error loading No::Such::Check});
}


sub croaks_on_wrong_config_syntax_modules_not_object : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": "DummyCheck" }');
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{must be a json object}i);
}


sub logs_loaded_modules : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "Comic::Check::Actors": [] } }');
    $comics->load_settings("settings.json");
    stdout_like { $comics->load_checks(); } qr/^Checks modules loaded:\s+Comic::Check::Actors\s*$/m;
}


sub skips_non_module_settings : Tests {
    MockComic::fake_file("settings.json", '{ "Checks": { "foo": "bar" } }');
    $comics->load_settings("settings.json");

    $comics->load_checks();

    is(@{$comics->{checks}}, 0, 'should have no check modules');
    is_deeply($comics->{settings}->{settings}->{Checks}, { 'foo' => 'bar'}, 'wrong settings');
}
