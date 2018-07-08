use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub no_tags : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    $comic->_check_tags('tags', 'English');
    is_deeply($comic->{warnings}, []); # it's ok to not use tags
}


sub empty_tags : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => []});
    $comic->_check_tags('tags', 'English');
    is_deeply($comic->{warnings}, []);
}


sub tags_ok : Tests {
    MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    $comic->_check_tags('tags', 'English');
    is_deeply($comic->{warnings}, []);
}


sub tag_case : Tests {
    MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['Tag1']});
    $comic->_check_tags('tags', 'English');
    is_deeply($comic->{warnings}, ['tags Tag1 and tag1 from some_comic.svg only differ in case']);
}
