use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't/out';
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


sub croaks_if_no_configuration : Tests {
    eval {
        $comics->load_generators();
    };
    like($@, qr{no output generator}i);
}


sub croaks_if_no_out_configuration : Tests {
    $faked_files{'config.json'} = '{}';
    $comics->load_settings('config.json');
    eval {
        $comics->load_generators();
    };
    like($@, qr{no output generator}i);
}


sub croaks_if_out_configuration_is_empty : Tests {
    $faked_files{'config.json'} = <<'JSON';
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
    $faked_files{'config.json'} = <<'JSON';
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


sub needs_something_else : Tests {
    my $obj = Comic::Out::Generator->new();
    my $gen = Comic::Out::Generator->new('key' => $obj);

    $gen->needs('key', 'Comic::Out::Generator');  # would croak if it failed
    is_deeply($gen->{settings}->{'key'}, $obj);
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
