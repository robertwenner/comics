use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Comic::Check::Tag;

__PACKAGE__->runtests() unless caller;


my $check;


sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::Tag->new('tags');
}


sub no_tags : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::TAGS => {},
        $MockComic::PUBLISHED_WHEN => '3016-01-01');
    $check->check($comic);
    is_deeply($comic->{warnings}, ["Comic::Check::Tag: No English tags"]);
}


sub empty_tags_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => []});
    $check->check($comic);
    is_deeply($comic->{warnings}, ["Comic::Check::Tag: No English tags"]);
}


sub empty_tags_text : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => [""]});
    $check->check($comic);
    is_deeply($comic->{warnings}, ["Comic::Check::Tag: Empty English tags"]);
}


sub equal_tags: Tests {
    my $comic1 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    my $comic2 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    $check->check($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, []);
}


sub tag_case_differences : Tests {
    my $comic1 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1']});
    my $comic2 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['Tag1']});
    $check->notify($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, ["Comic::Check::Tag: tags 'Tag1' and 'tag1' from some_comic.svg only differ in case"]);
}


sub tag_whitespace_differences : Tests {
    my $comic1 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => {$MockComic::ENGLISH => [' tag 1']});
    my $comic2 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => {$MockComic::ENGLISH => ['tag1\t']});
    $check->notify($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, ["Comic::Check::Tag: tags 'tag1\t' and ' tag 1' from some_comic.svg only differ in white space"]);
}


sub multiple_tags : Tests {
    my $comic1 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TAGS => { $MockComic::ENGLISH => ['beer', 'craft'] },
        $MockComic::WHO => {$MockComic::ENGLISH => ['tag 1']});
    my $comic2 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "a comic" },
        $MockComic::PUBLISHED_WHEN => '3016-01-02',
        $MockComic::TAGS => { $MockComic::ENGLISH => ['beer', 'craft'] },
        $MockComic::WHO => {$MockComic::ENGLISH => ['tag1']});
    $check = Comic::Check::Tag->new('tags', 'who');
    $check->notify($comic1);
    $check->check($comic2);
    is_deeply($comic2->{warnings}, ["Comic::Check::Tag: who 'tag1' and 'tag 1' from some_comic.svg only differ in white space"]);
}


sub does_not_modify_tags : Tests {
    $check = Comic::Check::Tag->new('tags');
    my $other_comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Something else' },
        $MockComic::TAGS => { $MockComic::ENGLISH => [ 'something', 'else' ] },
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Purity law' },
        $MockComic::TAGS => { $MockComic::ENGLISH => [ 'purity law' ] },
    );

    $check->notify($comic);
    $check->notify($other_comic);
    $check->check($comic);
    $check->check($other_comic);

    is_deeply($comic->{meta_data}->{tags}, { 'English' => ['purity law'] });
}


sub does_not_modify_tags_different_comics_multiple_tags : Tests {
    $check = Comic::Check::Tag->new('tags');
    my $first = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Purity' },
        $MockComic::TAGS => { $MockComic::ENGLISH => [ 'purity law', 'law of purity' ] },
    );
    my $second = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'More purity' },
        $MockComic::TAGS => { $MockComic::ENGLISH => [ 'purity law', 'law of purity' ] },
    );

    $check->notify($first);
    $check->notify($second);
    $check->check($first);
    $check->check($second);

    is_deeply($first->{warnings}, [], 'first should not have warnings');
    is_deeply($second->{warnings}, [], 'second should not have warnings');

    is_deeply($first->{meta_data}->{tags}, { 'English' => ['purity law', 'law of purity'] });
    is_deeply($second->{meta_data}->{tags}, { 'English' => ['purity law', 'law of purity'] });
}


sub does_not_check_comic_against_itself : Tests {
    $check = Comic::Check::Tag->new('tags');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Purity law comic' },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['purity law', 'law of purity'],
        },
    );

    $check->notify($comic);
    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}
