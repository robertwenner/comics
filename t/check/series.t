use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::Series;

__PACKAGE__->runtests() unless caller;


my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::Series->new();
}


sub happy_with_no_series : Tests {
    my $comic = MockComic::make_comic();
    $check->check($comic);
    $check->final_check();
    is_deeply([@{$comic->{warnings}}], []);
}


sub happy_with_repeated_series_per_language : Tests {
    my @comics;
    foreach my $i (1..3) {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::DEUTSCH => 'Comic',
            },
            $MockComic::SERIES => {
                $MockComic::DEUTSCH => 'Buckimude',
            },
        );
        $check->check($comic);
        push @comics, $comic;
    }
    $check->final_check();
    foreach my $comic (@comics) {
        is_deeply([@{$comic->{warnings}}], []);
    }
}


sub warns_if_unique_series : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Comic',
        },
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => 'Buckimude',
        },
    );
    $check->notify($comic);
    $check->final_check();
    is_deeply([@{$comic->{warnings}}], [
        'Deutsch has only one comic in the \'Buckimude\' series',
    ]);
}


sub warns_if_unique_series_ignores_surrounding_whitespace : Tests {
    my $c1 = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Comic1',
        },
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => 'Buckimude',
        },
    );
    $check->notify($c1);
    my $c2 = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Comic2',
        },
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => ' Buckimude ',
        },
    );
    $check->notify($c1);
    $check->final_check();
    is_deeply([@{$c1->{warnings}}], []);
    is_deeply([@{$c2->{warnings}}], []);
}


sub complains_if_unique_series_per_language : Tests {
    my $de = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Comic',
        },
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => 'oops'
        },
    );
    $check->notify($de);
    my $en = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Comic',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'oops'
        },
    );
    $check->notify($en);
    $check->final_check();
    is_deeply([@{$de->{warnings}}],
        ['Deutsch has only one comic in the \'oops\' series']);
    is_deeply([@{$en->{warnings}}],
        ['English has only one comic in the \'oops\' series']);
}


sub series_not_in_all_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => 'Buckimude'
        },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
    $check->check($comic);
    is_deeply([@{$comic->{warnings}}],
        ['No series tag for English but for Deutsch']);
}


sub series_not_in_all_languages_empty : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => 'Buckimude',
            $MockComic::ENGLISH => ''
        },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
    $check->check($comic);
    is_deeply([@{$comic->{warnings}}],
        ['No series tag for English but for Deutsch', 'Empty series for English']);
}


sub different_language_same_series : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => 'Buckimude',
            $MockComic::ENGLISH => 'Buckimude',
        },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
    $check->check($comic);
    is_deeply([@{$comic->{warnings}}],
        ["Duplicated series tag 'Buckimude' for English and Deutsch",
         "Duplicated series tag 'Buckimude' for Deutsch and English"]);
}


sub duplicate_series_does_not_hide_later_error : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Comic',
            $MockComic::ENGLISH => 'Comic',
            $MockComic::ESPAÑOL => 'Comic',
        },
        $MockComic::SERIES => {
            $MockComic::DEUTSCH => 'Buckimude',
            $MockComic::ENGLISH => 'Buckimude',
        },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
    $check->check($comic);
    my %warned = map { $_ => 1 } @{$comic->{warnings}};
    ok($warned{"No series tag for Español but for Deutsch"});
}
