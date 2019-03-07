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


sub no_duplicate_warnings_general : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    stdout_like {
        $comic->_warn("a");
        $comic->_warn("a");
        $comic->_warn("b");
        $comic->_warn("c");
        $comic->_warn("b");
        $comic->_warn("b");
    }
    qr{some_comic.svg : a\r?\nsome_comic.svg : b\r?\nsome_comic.svg : c\r?\nsome_comic.svg : b\r?\n};
    is_deeply($comic->{warnings}, ['a', 'b', 'c', 'b']);
}


sub warn_croaks_on_published : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-01');
    eval {
        $comic->_warn("a");
    };
    like($@, qr{some_comic\.svg : a\b.*}i);
}


sub warning_includes_source_file_name : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    stdout_like { $comic->_warn("oops"); } qr{some_comic\.svg : oops\b.*}i;
}
