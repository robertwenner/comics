use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't/check';

use File::Slurper;
use Comics;

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
    *File::Slurper::read_text = sub {
        my ($file) = @_;
        return $faked_files{$file};
    };
    use warnings;

    $comics = Comics->new();
}


sub config_file_does_not_exist : Tests {
    $comics->load_settings("config.json");

    isnt($comics->{settings}, undef, 'should have initialized settings');
    is_deeply($comics->{settings}->get(), {}, 'settings shoud be empty');
    is_deeply($asked_exists{"config.json"}, 1, 'should have looked for config file');
}


sub laods_config_file : Tests {
    $faked_files{"config.json"} = '{"foo": "bar"}';

    $comics->load_settings("config.json");
    is_deeply({"foo" => "bar"}, $comics->{settings}->get(), 'should have loaded settings');
}


sub uses_all_checks_if_nothing_configured : Tests {
    $comics->load_checks();
    ok($comics->{checks} > 0, 'should have checks');
}


sub uses_all_checks_if_no_checks_config_section_exists : Tests {
    $faked_files{"settings.json"} = '{}';
    $comics->load_settings("settings.json");
    $comics->load_checks();
    ok($comics->{checks} > 0, 'should have checks');
}


sub uses_no_checks_if_checks_config_section_is_empty : Tests {
    $faked_files{"settings.json"} = '{ "Checks": {} }';
    $comics->load_settings("settings.json");
    $comics->load_checks();
    is_deeply($comics->{checks}, [], 'should not have checks');
}


sub passes_args_to_configured_check_from_list : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": [1, 2, 3] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, [1, 2, 3], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_from_object : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": {"a": 1} } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, ["a", 1], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_from_scalar_value : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": "a" } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, ["a"], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_null : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": null } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("DummyCheck"), 'created wrong check');
    is_deeply($comics->{checks}[0]->{args}, [], 'passed wrong ctor args');
}


sub passes_args_to_configured_check_boolean : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "DummyCheck.pm": true } }';
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{cannot handle}i);
}


sub uses_configured_check_path : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "Comic/Check/Actors.pm": [] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_check_module_name : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "Comic::Check::Actors": [] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub uses_configured_check_without_extension : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "Comic/Check/Actors": [] } }';
    $comics->load_settings("settings.json");
    $comics->load_checks();

    is(@{$comics->{checks}}, 1, 'should have one check');
    ok($comics->{checks}[0]->isa("Comic::Check::Actors"), 'created wrong check');
}


sub croaks_on_unknown_configured_check : Tests {
    $faked_files{"settings.json"} = '{ "Checks": { "NoSuchCheck": [] } }';
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{Can't locate NoSuchCheck});
}


sub croaks_on_wrong_config_syntax_checks_not_object : Tests {
    $faked_files{"settings.json"} = '{ "Checks": "DummyCheck" }';
    $comics->load_settings("settings.json");
    eval {
        $comics->load_checks();
    };
    like($@, qr{must be a json object}i);
}
