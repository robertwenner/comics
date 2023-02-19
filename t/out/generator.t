use strict;
use warnings;

use JSON;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use lib 't/out';
use Comics;

__PACKAGE__->runtests() unless caller;


my $comics;


sub set_up : Test(setup) {
    MockComic::set_up();
    $comics = Comics->new();
}


sub croaks_if_no_configuration : Tests {
    eval {
        $comics->load_generators();
    };
    like($@, qr{no output generator}i);
}


sub croaks_if_no_out_configuration : Tests {
    MockComic::fake_file('config.json', '{}');
    $comics->load_settings('config.json');
    eval {
        $comics->load_generators();
    };
    like($@, qr{no output generator}i);
}


sub croaks_if_out_configuration_is_empty : Tests {
    MockComic::fake_file('config.json', <<'JSON');
{
    "Out": {
    }
}
JSON
    $comics->load_settings('config.json');
    eval {
        $comics->load_generators();
    };
    like($@, qr{no output generator}i);
}


sub loads_generators : Tests {
    MockComic::fake_file('config.json', <<'JSON');
{
    "Out": {
        "DummyGenerator": []
    }
}
JSON
    $comics->load_settings('config.json');
    $comics->load_generators();
    ok($comics->{settings}->get()->{Out});  # not empty
}


sub needs_not_given : Tests {
    my $gen = Comic::Out::Generator->new();
    eval {
        $gen->needs('oops', '');
    };
    like($@, qr{Comic::Out::Generator}, 'should mention module');
    like($@, qr{\boops\b}i, 'should say what key is missing');
    like($@, qr{must specify}i, 'should say what is wrong');
}


sub needs_scalar : Tests {
    my $gen = Comic::Out::Generator->new('key' => 1);

    is($gen->{settings}->{'key'}, 1);
    $gen->needs('key', '');  # would croak if it failed

    eval {
        $gen->needs('key', 'hash');
    };
    like($@, qr{Comic::Out::Generator}, 'should mention module');
    like($@, qr{key}, 'should mention key');
    like($@, qr{hash}i, 'should mention expected type');

    eval {
        $gen->needs('key', 'array');
    };
    like($@, qr{Comic::Out::Generator}, 'should mention module');
    like($@, qr{key}, 'should mention key');
    like($@, qr{array}i, 'should mention expected type');
}


sub needs_hash : Tests {
    my $gen = Comic::Out::Generator->new('key' => {'a' => 1});

    is_deeply($gen->{settings}->{'key'}, {'a' => 1});

    $gen->needs('key', 'HASH');  # would croak if it failed
    eval {
        $gen->needs('key', 'ARRAY');
    };
    like($@, qr{Comic::Out::Generator}, 'should mention module');
    like($@, qr{\bmust be array\b}i, 'should say what was expected');
    like($@, qr{\bis hash\b}i, 'should say what it got');
}


sub needs_array : Tests {
    my $gen = Comic::Out::Generator->new('key' => [1, 2, 3]);

    is_deeply($gen->{settings}->{'key'}, [1, 2, 3]);

    $gen->needs('key', 'ARRAY');  # would croak if it failed
    eval {
        $gen->needs('key', '');
    };
    like($@, qr{Comic::Out::Generator}, 'should mention module');
    like($@, qr{\bmust be scalar\b}i, 'should say what was expected');
    like($@, qr{\bis array\b}i, 'should say what it got');
}


sub needs_directory_no_trailing_slash : Tests {
    my $gen = Comic::Out::Generator->new('key' => 'dir');

    $gen->needs('key', 'directory');  # would croak if it failed
    is($gen->{settings}->{'key'}, 'dir/');
}


sub needs_directory_with_trailing_slash : Tests {
    my $gen = Comic::Out::Generator->new('key' => 'dir/');

    $gen->needs('key', 'directory');  # would croak if it failed
    is($gen->{settings}->{'key'}, 'dir/');
}


sub needs_hash_or_scalar : Tests {
    my $gen = Comic::Out::Generator->new(
        'scalar' => 'value',
        'hash' => {
            '1' => 'one',
        },
        'array' => [],
    );

    $gen->needs('scalar', 'hash-or-scalar');  # would croak if it failed
    is($gen->{settings}->{'scalar'}, 'value');

    $gen->needs('hash', 'hash-or-scalar');  # would croak if it failed
    is_deeply($gen->{settings}->{'hash'}, {'1' => 'one'});

    eval {
        $gen->needs('array', 'hash-or-scalar');
    };
    like($@, qr{must be hash or scalar});
}


sub optional_settings_type_check : Tests {
    my $gen = Comic::Out::Generator->new(
        's-value' => [],
        'h-value' => 1,
        'a-value' => {},
        's-or-a-value' => {},
    );

    eval {
        $gen->optional('s-value', 'hash-or-scalar');
    };
    like($@, qr{s-value});
    like($@, qr{hash});
    like($@, qr{scalar});

    eval {
        $gen->optional('h-value', 'hash');
    };
    like($@, qr{h-value});
    like($@, qr{hash});

    eval {
        $gen->optional('a-value', 'array');
    };
    like($@, qr{a-value});
    like($@, qr{array});
}


sub per_language_setting : Tests {
    my $gen = Comic::Out::Generator->new(
        'template' => 'en.templ',
        'outfile' => {
            'English' => 'out-en.html',
        }
    );

    is($gen->per_language_setting('template', 'English'), 'en.templ', 'wrong template');
    is($gen->per_language_setting('outfile', 'English'), 'out-en.html', 'wrong outfile');
}


sub complains_about_unknown_settings : Tests {
    my $gen = Comic::Out::Generator->new(
        'a' => '1',
        'whatever' => '...',
    );

    $gen->optional('a', 'scalar', 1);
    eval {
        $gen->flag_extra_settings();
    };
    like($@, qr{Comic::Out::Generator}, 'should mention module');
    like($@, qr{unknown}, 'should state problem');
    like($@, qr{whatever}, 'should mention bad setting');
}


sub complains_about_unknown_type : Tests {
    eval {
        Comic::Out::Generator::_type_name('whatever');
    };
    like($@, qr{\bunknown\b}i, 'says what the problem is');
    like($@, qr{\btype\b}i, 'says what is bad');
    like($@, qr{\bwhatever\b}, 'gives the unknown value');
}


sub handles_json_boolean : Tests {
    my $json = '{ "T": true, "F": false }';
    my $decoded = decode_json($json);

    my $gen = Comic::Out::Generator->new(%{$decoded});
    $gen->optional('T', 'scalar', 1);
    $gen->optional('F', 'scalar', 0);

    ok($gen->{settings}{'T'});
    ok(!$gen->{settings}{'F'});
}


sub base_generator_is_up_to_date : Tests {
    my $gen = Comic::Out::Generator->new();
    ok($gen->up_to_date());
}
