use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Comics;
use Comic;

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
    local *File::Slurp::slurp = sub {
        push @loaded, @_;
        return "{}";
    };
    use warnings;

    my $comics = Comics->new();
    $comics->load_settings("one", "two", "three");

    is_deeply(\@loaded, ["one", "two", "three"]);
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
