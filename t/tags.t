use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub makeComic {
    return MockComic::make_comic(
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['en1', 'en2'],
            $MockComic::DEUTSCH => ['de1'],
        }
    );
}


sub setup : Test(setup) {
    MockComic::set_up();
}


sub tags_unknown_language : Test {
    makeComic()->_count_tags();
    is(Comic::counts_of_in("tags", "Pimperanto"), undef);
}


sub tags_per_language : Tests {
    makeComic()->_count_tags();
    is_deeply(Comic::counts_of_in("tags", "English"), { "en1" => 1, "en2", => 1 });
    is_deeply(Comic::counts_of_in("tags", "Deutsch"), { "de1" => 1 });
}


sub tags_multiple_times : Test {
    makeComic()->_count_tags();
    makeComic()->_count_tags();
    makeComic()->_count_tags();
    is_deeply(Comic::counts_of_in("tags", "English"), { "en1" => 3, "en2", => 3 });
}
