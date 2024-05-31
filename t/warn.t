use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::Output;

use lib 't';
use MockComic;
use lib 't/out';
use DummyGenerator;

use Comics;

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


sub comics_generate_writes_warnings_to_stdout : Tests {
    my $config = <<"END";
{
    "Domains": {
        "Deutsch": "biercomics.de",
        "English": "beercomics.com"
    },
    "Out": {
        "DummyGenerator": {}
    },
    "Checks": {
        "Comic::Check::DontPublish": [ "oops" ]
    }
}
END
    MockComic::fake_file('settings.json', $config);
    no warnings qw/redefine/;
    *File::Util::file_type = sub { return 'FILE'; };
    use warnings;
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'oops',
        },
        $MockComic::PUBLISHED_WHEN => '2000-01-01',
    );

    stdout_like {
        Comics::generate('settings.json', 'some_comic.svg');
    } qr{\bsome_comic\.svg\b.+\boops\b}s;
}


sub comics_generate_croaks_on_warnings_for_unpublished_comic : Tests {
    my $config = <<"END";
{
    "Domains": {
        "Deutsch": "biercomics.de",
        "English": "beercomics.com"
    },
    "Out": {
        "DummyGenerator": {}
    },
    "Checks": {
        "Comic::Check::DontPublish": [ "oops", "upsi" ]
    }
}
END
    MockComic::fake_file('settings.json', $config);
    no warnings qw/redefine/;
    *File::Util::file_type = sub { return 'FILE'; };
    use warnings;
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'oops',
            $MockComic::DEUTSCH => 'upsi',
        },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );

    eval {
       stdout_like {
           Comics::generate('settings.json', 'some_comic.svg');
       } qr{\bsome_comic\.svg\b.+\boops\b.+\b2 problems\b}s;
    };
    like($@, qr{2 problems in some_comic.svg});
}
