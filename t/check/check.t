use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use File::Slurper;
use Comic::Check::Check;
use Comics;

use lib 't/check';
use BadCheck;


__PACKAGE__->runtests() unless caller;

my %faked_files;
my $comics;


sub set_up : Test(setup) {
    %faked_files = ();

    no warnings qw/redefine/;
    *Comics::_exists = sub {
        my ($file) = @_;
        return defined $faked_files{$file};
    };
    *File::Slurper::read_text = sub {
        my ($file) = @_;
        return $faked_files{$file};
    };
    use warnings;

    $comics = Comics->new();
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


sub base_final_check_does_nothing : Tests {
    my $check = Comic::Check::Check->new();
    is($check->final_check(), undef);
}


sub base_check_confesses_if_not_overridden : Tests {
    my $check = BadCheck->new();

    eval {
        $check->check();
    };

    like($@, qr{\boverridden\b}m, 'should mention problem');
    like($@, qr{\bBadCheck\b}m, 'should mention broken module');
    like($@, qr{\bComic::Check::Check::check\b}m, 'should mention method name');
}
