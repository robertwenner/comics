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


sub croaks_if_no_out_configuration : Test {
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
        "DummyGenerator": {},
    }
}
JSON
    $comics->load_settings('config.json');
    $comics->load_generators();
    ok($comics->{settings}->get()->{Out});  # not empty
}
