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


sub happy_with_no_series_tags : Tests {
    my $comic = MockComic::make_comic();
    Comic::_check_series_tags();
    is_deeply([@{$comic->{warnings}}], []);
}


sub happy_with_multiple_tags_per_language : Tests {
    my @comics;
    foreach my $i (1..3) {
        push @comics, MockComic::make_comic($MockComic::SERIES => {
                $MockComic::DEUTSCH => 'Buckimude'},
            $MockComic::PUBLISHED_WHEN => '3016-01-01',
        );
    }
    foreach my $comic (@comics) {
        Comic::_check_series_tags();
        is_deeply([@{$comic->{warnings}}], []);
    }
}


sub complains_if_unique_tag : Tests {
    my $comic = MockComic::make_comic($MockComic::SERIES => {
            $MockComic::DEUTSCH => 'Buckimude'},
        $MockComic::PUBLISHED_WHEN => '3016-01-01');
    Comic::_check_series_tags();
    is_deeply([@{$comic->{warnings}}],
        ['Deutsch has only one comic in the \'Buckimude\' series']);
}


sub complains_if_unique_tag_per_language : Tests {
    my $de = MockComic::make_comic($MockComic::SERIES => {
            $MockComic::DEUTSCH => 'oops'},
        $MockComic::PUBLISHED_WHEN => '3016-01-01');
    my $en = MockComic::make_comic($MockComic::SERIES => {
            $MockComic::ENGLISH => 'oops'},
        $MockComic::PUBLISHED_WHEN => '3016-01-01');
    Comic::_check_series_tags();
    is_deeply([@{$de->{warnings}}],
        ['Deutsch has only one comic in the \'oops\' series']);
    is_deeply([@{$en->{warnings}}],
        ['English has only one comic in the \'oops\' series']);
}
