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


sub multiple_comics_different_languages : Tests {
    my $de = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Neustes Comic' },
    );
    my $en = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    my %tweeted;
    no warnings qw/redefine/;
    local *Comic::_tweet = sub {
        my ($comic, $language) = @_;
        $tweeted{$language} = $comic;
    };
    local *Comic::_reddit = sub {
        return '';
    };
    use warnings;

    Comic::post_to_social_media();
    is_deeply(\%tweeted, {'English' => $en, 'Deutsch' => $de}, 'Tweeted wrong comics');
}


sub only_latest_comics : Tests {
    my $old = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Old comic' },
        $MockComic::PUBLISHED_WHEN => '2010-01-01',
    );
    my $current1 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    my $current2 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Also latest comic' },
    );
    my $future = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Way too new comic' },
        $MockComic::PUBLISHED_WHEN => '2121-01-01',
    );

    my @tweeted;
    no warnings qw/redefine/;
    local *Comic::_tweet = sub {
        my ($comic, $language) = @_;
        push @tweeted, $comic;
    };
    local *Comic::_reddit = sub {
        return '';
    };
    use warnings;

    Comic::post_to_social_media();
    is_deeply(\@tweeted, [$current2, $current1], 'Tweeted wrong comics');
}


sub subreddit_from_meta_data_override : Tests {
    my $json = <<'JSON';
            "reddit": {
                "use-default": false,
                "English": {
                    "subreddit": "homebrewing"
                },
                "Deutsch": {
                    "subreddit": "heimbrauen"
                }
            }
JSON
    MockComic::make_comic(
        $MockComic::JSON => $json,
    );
    my %subreddits;
    no warnings qw/redefine/;
    local *Comic::_reddit = sub {
        my ($comic, $language, %settings) = @_;
        push @{$subreddits{$language}}, $settings{subreddit};
    };
    local *Comic::_tweet = sub {
        return '';
    };
    use warnings;

    Comic::post_to_social_media(reddit => { subreddit => 'comics'});
    is_deeply(\%subreddits,
        { 'Deutsch' => ['heimbrauen'], 'English' => ['homebrewing'] });
}


sub subreddit_from_meta_data_plus_default : Tests {
    my $json = <<'JSON';
            "reddit": {
                "use-default": true,
                "English": {
                    "subreddit": "homebrewing"
                },
                "Deutsch": {
                    "subreddit": "heimbrauen"
                }
            }
JSON
    MockComic::make_comic(
        $MockComic::JSON => $json,
    );
    my %subreddits;
    no warnings qw/redefine/;
    local *Comic::_reddit = sub {
        my ($comic, $language, %settings) = @_;
        push @{$subreddits{$language}}, $settings{subreddit};
    };
    local *Comic::_tweet = sub {
        return '';
    };
    use warnings;

    Comic::post_to_social_media(reddit => { subreddit => 'comics'});
    is_deeply(\%subreddits,
        { 'Deutsch' => ['comics', 'heimbrauen'], 'English' => ['comics', 'homebrewing'] });
}


sub subreddit_from_meta_data_array : Tests {
    my $json = <<'JSON';
            "reddit": {
                "use-default": false,
                "English": {
                    "subreddit": [ "foo", "bar", "baz" ]
                }
            }
JSON
    MockComic::make_comic(
        $MockComic::JSON => $json,
    );
    my %subreddits;
    no warnings qw/redefine/;
    local *Comic::_reddit = sub {
        my ($comic, $language, %settings) = @_;
        push @{$subreddits{$language}}, $settings{subreddit};
    };
    local *Comic::_tweet = sub {
        return '';
    };
    use warnings;

    Comic::post_to_social_media(reddit => { subreddit => 'comics'});
    is_deeply(\%subreddits, { 'English' => ['foo', 'bar', 'baz'] });
}


sub preserves_reddit_options_for_each_subreddit : Tests {
    my $json = <<'JSON';
            "reddit": {
                "use-default": false,
                "English": {
                    "client": "me",
                    "subreddit": "foo",
                    "key": "value",
                    "arr": [ 1, 2, 3]
                }
            }
JSON
    MockComic::make_comic(
        $MockComic::JSON => $json,
    );
    my %options;
    no warnings qw/redefine/;
    local *Comic::_reddit = sub {
        my ($comic, $language, %settings) = @_;
        %options = %settings;
    };
    local *Comic::_tweet = sub {
        return '';
    };
    use warnings;

    Comic::post_to_social_media(reddit => { subreddit => 'comics'});
    is_deeply(\%options,
        { "client" => "me", "subreddit" => "foo", "key" => "value", "arr" => [1, 2, 3]});
}


sub combines_global_reddit_options_with_per_comic_options : Tests {
    my $json = <<'JSON';
            "reddit": {
                "use-default": false,
                "English": {
                    "subreddit": "foo"
                }
            }
JSON
    MockComic::make_comic(
        $MockComic::JSON => $json,
    );
    my %options;
    no warnings qw/redefine/;
    local *Comic::_reddit = sub {
        my ($comic, $language, %settings) = @_;
        %options = %settings;
    };
    local *Comic::_tweet = sub {
        return '';
    };
    use warnings;

    Comic::post_to_social_media(reddit => { subreddit => 'comics', username => 'me', password => 'secret'});
    is_deeply(\%options, { username => 'me', password => 'secret', subreddit => 'foo' });
}
