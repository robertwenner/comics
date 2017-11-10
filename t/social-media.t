use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


my %file;
my %desc;
my %reddit;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));

    no warnings qw/redefine/;
    *Comic::_tweet = sub {
        my ($file, $language, $desc) = @_;
        $file{$language} = $file;
        $desc{$language} = $desc;
    };
    *Comic::_reddit = sub {
        ($reddit{'link'}, $reddit{'title'}, $reddit{'subreddit'}) = @_;
    };
    use warnings;

    %file = ();
    %desc = ();
    %reddit = ();
}


sub tweets : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    Comic::post_to_social_media('png', 'English');
    is($file{$MockComic::ENGLISH}, 'generated/english/web/comics/latest-comic.png');
    is($desc{$MockComic::ENGLISH}, 'This is the latest beercomic!');
}


sub shortens_twitter_text : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'x' x 290 },
    );
    Comic::post_to_social_media('png', 'English');
    is($desc{$MockComic::ENGLISH}, 'x' x 280);
}


sub hashtags : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'] },
    );
    Comic::post_to_social_media('png', 'English');
    is($desc{$MockComic::ENGLISH}, '#beer #craftbeer @you Funny stuff');
}


sub multiple_languages : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Latest comic',
            $MockComic::DEUTSCH => 'Neustes Comic',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => 'Funny stuff',
            $MockComic::DEUTSCH => 'Lustiges Bier',
        },
        $MockComic::TWITTER => {
            $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'],
            $MockComic::DEUTSCH => ['#Bier', '#selbstbrauen', '@duda'],
        },
    );
    Comic::post_to_social_media('png', $MockComic::ENGLISH, $MockComic::DEUTSCH);
    is($desc{$MockComic::ENGLISH}, '#beer #craftbeer @you Funny stuff');
    is($desc{$MockComic::DEUTSCH}, '#Bier #selbstbrauen @duda Lustiges Bier');
}


sub no_languages_tweets_all_languages_with_meta_data : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Latest comic',
            $MockComic::DEUTSCH => 'Neustes Comic',
            $MockComic::ESPAÑOL => 'Comico nuevo',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => 'Funny stuff',
            $MockComic::DEUTSCH => 'Lustiges Bier',
            $MockComic::ESPAÑOL => 'Que risa cerveza',
        },
        $MockComic::TWITTER => {
            $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'],
            $MockComic::DEUTSCH => ['#Bier', '#selbstbrauen', '@duda'],
            # no Twitter tags for Spanish; ignore it
        },
    );
    Comic::post_to_social_media('png');
    is($desc{$MockComic::ENGLISH}, '#beer #craftbeer @you Funny stuff');
    is($file{$MockComic::ENGLISH}, 'generated/english/web/comics/latest-comic.png');
    is($desc{$MockComic::DEUTSCH}, '#Bier #selbstbrauen @duda Lustiges Bier');
    is($file{$MockComic::DEUTSCH}, 'generated/deutsch/web/comics/neustes-comic.png');
    is($desc{$MockComic::ESPAÑOL}, undef);
    is($file{$MockComic::ESPAÑOL}, undef);
}


sub test_resets_comics : Tests {
    # Makes sure I don't forget to clear the %desc and %file hashes between tests.
    is($desc{$MockComic::ENGLISH}, undef);
}


sub does_not_tweet_if_no_new_comic : Tests {
    MockComic::fake_now(DateTime->new(year => 2017, month => 2, day => 1));
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::PUBLISHED_WHEN => '2017-01-01',
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'] },
    );
    eval {
        Comic::post_to_social_media('png');
    };
    like($@, qr(Not posting), 'Error message');
    like($@, qr(2017-01-01), 'Includes date of the comic');
    is($desc{$MockComic::ENGLISH}, undef);
}


sub complains_about_bad_mode : Tests {
    eval {
        Comic::post_to_social_media('whatever');
    };
    like($@, qr(Unknown twitter mode 'whatever'));
    eval {
        Comic::post_to_social_media();
    };
    like($@, qr(Missing twitter mode));
}


sub html_tweet : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'] },
    );
    Comic::post_to_social_media('html', 'English');

    is($file{$MockComic::ENGLISH}, 'https://beercomics.com/comics/latest-comic.html');
}


sub post_to_reddit_adds_oc_tag_and_subreddit : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
    );
    Comic::post_to_social_media('html', 'English');
    is($reddit{'title'}, '[OC] Latest comic');
    is($reddit{'link'}, 'https://beercomics.com/comics/latest-comic.html');
    is($reddit{'subreddit'}, 'comics');
}


sub post_to_reddit_retries_on_rate_limit : Tests {
    my $slept;
    no warnings qw/redefine/;
    local *Comic::_sleep = sub {
        $slept = $_[0];
    };
    use warnings;

    my $comic = MockComic::make_comic();

    Comic::_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 9 minutes.');
    is($slept, 60 * 9);

    Comic::_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 10 seconds.');
    is($slept, 10);

    eval {
        Comic::_wait_for_reddit_limit('Error(s): whatever');
    };
    like($@, qr{Don't know what reddit complains about}i);
}


__END__
sub toots : Tests {
}
