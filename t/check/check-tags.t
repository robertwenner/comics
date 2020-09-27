use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


my $check;


sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::Tag->new('who', 'tags');
}


sub no_tags : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01');
    $check->check($comic);
    is_deeply($comic->{warnings}, []); # it's ok to not use tags
}


sub empty_tags : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => []});
    $check->check($comic);
    is_deeply($comic->{warnings}, []);
}


sub equal_tags: Tests {
    my $comic1 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    my $comic2 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    $check->check($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, []);
}


sub tag_case_differences : Tests {
    my $comic1 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    my $comic2 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['Tag1']});
    $check->notify($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, ["tags 'Tag1' and 'tag1' from some_comic.svg only differ in case"]);
}


sub tag_whitespace_differences : Tests {
    my $comic1 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => [' tag 1']});
    my $comic2 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1\t']});
    $check->notify($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, ["tags 'tag1\t' and ' tag 1' from some_comic.svg only differ in white space"]);
}


sub multiple_tags : Tests {
    my $comic1 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::WHO => {$MockComic::ENGLISH => ['tag 1']});
    my $comic2 = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::WHO => {$MockComic::ENGLISH => ['tag1']});
    $check->notify($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, ["who 'tag1' and 'tag 1' from some_comic.svg only differ in white space"]);
}
