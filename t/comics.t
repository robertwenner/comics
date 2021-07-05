use strict;
use warnings;

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

    no warnings qw/redefine/;
    local *Comics::_exists = sub {
        return 1;
    };
    local *File::Slurper::read_text = sub {
        push @loaded, @_;
        return "{}";
    };
    use warnings;

    my $comics = Comics->new();
    $comics->load_settings("one", "two", "three");

    is_deeply(\@loaded, ["one", "two", "three"]);
}


sub collect_files_adds_files_right_away : Tests {
    no warnings qw/redefine/;
    local *Comics::_is_directory = sub {
        return 0;
    };
    use warnings;

    my $comics = Comics->new();
    my @collection = $comics->collect_files('a.svg', 'foo', 'bar.txt');
    is_deeply([@collection], ['a.svg', 'foo', 'bar.txt']);
}


sub collect_files_recurses_in_directories : Tests {
    my @to_be_found = ('comic.svg', 'other file', 'file.svg~');

    no warnings qw/redefine/;
    local *Comics::_is_directory = sub {
        return 1;
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


sub runs_global_final_checks : Tests {
    my $comics = Comics->new();
    my $check = DummyCheck->new();
    push @{$comics->{checks}}, $check;
    $comics->final_checks();
    is(1, $check->{calls}{"final_check"});
}


sub runs_per_comic_final_checks : Tests {
    my $comics = Comics->new();
    my $comic = MockComic::make_comic();
    my $check = DummyCheck->new();
    push @{$comic->{checks}}, $check;
    push @{$comics->{comics}}, $comic;

    $comics->final_checks();
    is(1, $check->{calls}{"final_check"});
}


sub runs_each_final_check_only_once : Tests {
    my $comics = Comics->new();
    my $comic = MockComic::make_comic();
    my $global_check = DummyCheck->new();
    my $local_check = DummyCheck->new();

    push @{$comic->{checks}}, $global_check, $local_check;;
    push @{$comics->{checks}}, $global_check;
    push @{$comics->{comics}}, $comic;

    $comics->final_checks();
    is(1, $global_check->{calls}{"final_check"}, 'should have called global only once');
    is(1, $local_check->{calls}{"final_check"}, 'should have called local only once');
}
