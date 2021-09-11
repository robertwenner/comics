use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't/check';

use Comics;
use Comic::Modules;

__PACKAGE__->runtests() unless caller;

my %faked_files;
my %asked_exists;
my $comics;


sub set_up : Test(setup) {
    %faked_files = ();
    %asked_exists = ();

    no warnings qw/redefine/;
    *Comics::_exists = sub {
        my ($file) = @_;
        $asked_exists{$file}++;
        return defined $faked_files{$file};
    };
    *Comics::_is_directory = sub {
        return 0;
    };
    *File::Slurper::read_text = sub {
        my ($file) = @_;
        return $faked_files{$file};
    };
    use warnings;

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
    $faked_files{"config.json"} = '{"foo": "bar"}';

    $comics->load_settings("config.json");
    is_deeply({"foo" => "bar"}, $comics->{settings}->get(), 'should have loaded settings');
}


sub passes_args_to_configured_module_from_list : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": [1, 2, 3] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, [1, 2, 3], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_from_object : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": {"a": 1} } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, ["a", 1], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_from_scalar_value : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": "a" } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, ["a"], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_null : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": null } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, [], 'passed wrong ctor args');
}


sub passes_args_to_configured_module_boolean : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": true } }';
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{cannot handle}i);
}


sub uses_configured_module_path : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "Comic/Check/Actors.pm": [] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_module_name : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "Comic::Check::Actors": [] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_module_without_extension : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "Comic/Check/Actors": [] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub croaks_on_unknown_configured_module : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "NoSuchCheck": [] } }';
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{Can't locate NoSuchCheck});
}


sub croaks_on_wrong_config_syntax_modules_not_object : Tests {
    $faked_files{"settings.json"} = '{ "Checks": "DummyCheck" }';
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{must be a json object}i);
}
