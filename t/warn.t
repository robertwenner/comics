use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::Output;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub reports_problem_if_not_yet_published : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    $comic->warning("oops");
    like(${$comic->{warnings}}[0], qr{\boops\b});
}


sub suppresses_duplicate_warnings : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    $comic->warning("a");
    $comic->warning("a");
    $comic->warning("b");
    $comic->warning("c");
    $comic->warning("b");
    $comic->warning("b");
    is_deeply($comic->{warnings}, ['a', 'b', 'c', 'b']);
}


sub reports_problem_if_no_published_date : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '');
    $comic->warning("oops");
    like(${$comic->{warnings}}[0], qr{\boops\b});
}


sub checks_croaks_on_published : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-01');
    $comic->warning("oops");
    eval {
        $comic->check();
    };
    like($@, qr{1 problem}, 'should have an error message');
}


sub writes_warnings_to_stdout : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-01');
    stdout_like {
        $comic->warning("oops");
    } qr{\boops\b}i;
}


sub warning_on_stdout_includes_source_file_name : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    stdout_like {
        $comic->warning("oops");
    } qr{\bsome_comic\.svg\b};
}
