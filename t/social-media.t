use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));
}


sub no_new_comic : Tests {
    MockComic::fake_now(DateTime->new(year => 2017, month => 2, day => 1));
    MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2017-01-01');
    eval {
        Comic::post_to_social_media();
    };
    like($@, qr(Not posting)i, 'Did complain');
    like($@, qr(2017-01-01), 'Includes date of the latest comic');
}


sub for_languages : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Latest comic',
            $MockComic::DEUTSCH => 'Neustes Comic',
        },
    );

    my @tweet_languages;
    my @reddit_languages;

    no warnings qw/redefine/;
    local *Comic::_tweet = sub {
        my ($comic, $language) = @_;
        push @tweet_languages, $language;
    };
    local *Comic::_reddit = sub {
        my ($comic, $language) = @_;
        push @reddit_languages, $language;
    };
    use warnings;

    Comic::post_to_social_media();
    is_deeply([@tweet_languages], ['Deutsch', 'English'], 'wrong twitter languages');
    is_deeply([@reddit_languages], ['Deutsch', 'English'], 'wrong reddit languages');
}


sub passes_options : Tests {
    MockComic::make_comic($MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' });
    my %twitter;
    my %reddit;

    no warnings qw/redefine/;
    local *Comic::_tweet = sub {
        my ($comic, $language, %args) = @_;
        %twitter = %args;
    };
    local *Comic::_reddit = sub {
        my ($comic, $language, %args) = @_;
        %reddit = %args;
    };
    use warnings;

    Comic::post_to_social_media(
        twitter => {
            mode => 'png',
        },
        reddit => {
            blah => 'blubb',
        },
    );
    is_deeply(\%twitter, {mode => 'png'}, 'wrong twitter settings');
    is_deeply(\%reddit, {blah => 'blubb'}, 'wrong reddit settings');
}
