use strict;
use warnings;

use File::Util;
use base 'Test::Class';
use Test::More;

use Comics;

use lib 't';
use MockComic;
use lib 't/check';
use DummyCheck;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub load_settings : Tests {
    my @loaded;

    MockComic::fake_file('one', '{}');
    MockComic::fake_file('two', '{}');
    MockComic::fake_file('three', '{}');
    local *File::Slurper::read_text = sub {
        push @loaded, @_;
        return "{}";
    };
    use warnings;

    my $comics = Comics->new();
    $comics->load_settings("one", "two", "three");

    is_deeply(\@loaded, ["one", "two", "three"]);
}


sub config_does_not_exist : Tests {
    my $comics = Comics->new();
    eval {
        $comics->load_settings("oops");
    };
    like($@, qr{\bnot found\b}i, 'gives reason');
    like($@, qr{\boops\b}, 'includes file name');
}


sub config_is_directory : Tests {
    no warnings qw/redefine/;
    local *File::Util::file_type = sub {
        return ('BINARY', 'DIRECTORY');
    };
    use warnings;

    my $comics = Comics->new();
    eval {
        $comics->load_settings("oops");
    };
    like($@, qr{\bdirectory\b}i, 'gives reason');
    like($@, qr{\boops\b}, 'includes directory name');
}


sub collect_files_adds_files_right_away : Tests {
    MockComic::fake_file($_, '...') foreach (qw(a.svg foo bar.txt));

    my $comics = Comics->new();
    my @collection = $comics->collect_files('a.svg', 'foo', 'bar.txt');
    is_deeply([@collection], ['a.svg', 'foo', 'bar.txt']);
}


sub collect_files_recurses_in_directories : Tests {
    my @to_be_found = ('comic.svg', 'other file', 'file.svg~');

    local *File::Util::file_type = sub {
        my ($file) = @_;
        return $file eq 'dir' ? ('BINARY', 'DIRECTORY') : ('PLAIN', 'TEXT');
    };

    local *File::Find::find = sub {
        my ($wanted, @dirs) = @_;
        is_deeply([@dirs], ['dir'], 'passed wrong argument to find');
        foreach my $found (@to_be_found) {
            $File::Find::name = $found;
            $wanted->();
        }
    };
    use warnings;

    my $comics = Comics->new();
    is_deeply([$comics->collect_files('dir')], ['comic.svg']);
}


sub load_modules_empty_object_configured : Tests {
    my @loaded;
    no warnings qw/redefine/;
    local *Comic::Modules::load_module = sub {
        my ($name, @args) = @_;
        push @loaded, $name;
        return;
    };
    use warnings;
    MockComic::fake_file('settings.json', '{ "Checks": {} }');

    my $comics = Comics->new();
    $comics->load_settings('settings.json');

    $comics->load_checks();

    is_deeply(\@loaded, [], 'Should not have loaded check modules');
}


sub load_modules_one_module_configured : Tests {
    my @loaded;
    no warnings qw/redefine/;
    local *Comic::Modules::load_module = sub {
        my ($name, @args) = @_;
        push @loaded, $name;
        return;
    };
    use warnings;
    MockComic::fake_file('settings.json', '{ "Checks": {"Comic::Check::DummyCheck": {} } }');

    my $comics = Comics->new();
    $comics->load_settings('settings.json');

    $comics->load_checks();

    is_deeply(\@loaded, ['Comic::Check::DummyCheck'], 'Wrong check module');
}
