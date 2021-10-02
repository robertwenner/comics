use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

use Comic::Social::Reddit;

__PACKAGE__->runtests() unless caller;


my $reddit;


sub set_up : Test(setup) {
    MockComic::set_up();

    # The Reddit::Client constructor tries to authenticate... :-(
    no warnings qw/redefine/;
    *Reddit::Client::get_token = sub {
        return 1;
    };
    use warnings;

    $reddit = Comic::Social::Reddit->new({
        'Reddit' => {
            'username' => 'me',
            'password' => 'pass',
            'client_id' => 'client',
            'secret' => 'very secret',
			'default_subreddit' => '/r/comics',
        },
    });
}


sub fails_if_missing_configuration : Tests {
    eval {
        Comic::Social::Reddit->new();
    };
    like($@, qr{\bReddit\b}, 'should mention module');
    like($@, qr{\bconfiguration\b}i, 'should say what is missing');

    eval {
        Comic::Social::Reddit->new({
            'Reddit' => {
                'password' => '...',
                'client_id' => '...',
                'secret' => '...',
            },
        });
    };
    like($@, qr{\bReddit\b}, 'should mention module');
    like($@, qr{\username\b}i, 'should say what is missing');

    eval {
        Comic::Social::Reddit->new({
            'Reddit' => {
                'username' => '...',
                'client_id' => '...',
                'secret' => '...',
            },
        });
    };
    like($@, qr{\bReddit\b}, 'should mention module');
    like($@, qr{\bpassword\b}i, 'should say what is missing');

    eval {
        Comic::Social::Reddit->new({
            'Reddit' => {
                'username' => '...',
                'password' => '...',
                'secret' => '...',
            },
        });
    };
    like($@, qr{\bReddit\b}, 'should mention module');
    like($@, qr{\bclient_id\b}i, 'should say what is missing');

    eval {
        Comic::Social::Reddit->new({
            'Reddit' => {
                'username' => '...',
                'password' => '...',
                'client_id' => '...',
            },
        });
    };
    like($@, qr{\bReddit\b}, 'should mention module');
    like($@, qr{\bsecret\b}i, 'should say what is missing');
}


sub passes_options_to_reddit_client : Tests {
	my %passed;

	no warnings qw/redefine/;
	local *Reddit::Client::new = sub {
		shift @_;	# class
		%passed = @_;
		return;
	};
	use warnings;

	Comic::Social::Reddit->new({
        'Reddit' => {
            'username' => 'me',
            'password' => 'pass',
            'client_id' => 'client',
            'secret' => 'very secret',
			'client_settings' => {
				'foo' => 'bar',
			},
        },
    });
	my %expected = (
		'user_agent' => 'Comic::Social::Reddit by /u/beercomics',
		'username' => 'me',
		'password' => 'pass',
		'client_id' => 'client',
		'secret' => 'very secret',
		'foo' => 'bar',
	);
	is_deeply({%passed}, {%expected});
}


sub subreddit_from_configuration_scalar : Tests {
    my $comic = MockComic::make_comic();

	$reddit = Comic::Social::Reddit->new({
        'Reddit' => {
            'username' => 'me',
            'password' => 'pass',
            'client_id' => 'client',
            'secret' => 'very secret',
            'default_subreddit' => 'comics',
        },
    });

	is_deeply(['comics'], [$reddit->_get_subreddits($comic, 'Deutsch')]);
	is_deeply(['comics'], [$reddit->_get_subreddits($comic, 'English')]);
}


sub subreddit_from_configuration_array : Tests {
    my $comic = MockComic::make_comic();

    $reddit = Comic::Social::Reddit->new({
        'Reddit' => {
            'username' => 'me',
            'password' => 'pass',
            'client_id' => 'client',
            'secret' => 'very secret',
            'default_subreddit' => ['comics', 'funny'],
        },
    });

	is_deeply(['comics', 'funny'], [$reddit->_get_subreddits($comic, 'Deutsch')]);
	is_deeply(['comics', 'funny'], [$reddit->_get_subreddits($comic, 'English')]);
}


sub subreddit_from_configuration_invalid : Tests {
    my $comic = MockComic::make_comic();

    eval {
        Comic::Social::Reddit->new({
            'Reddit' => {
                'username' => 'me',
                'password' => 'pass',
                'client_id' => 'client',
                'secret' => 'very secret',
                'default_subreddit' => $comic,
            },
        });
    };
    like($@, qr{default_subreddit}, 'should mention bad param name');
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
    my $comic = MockComic::make_comic($MockComic::JSON => $json);

	is_deeply(['heimbrauen'], [$reddit->_get_subreddits($comic, 'Deutsch')]);
	is_deeply(['homebrewing'], [$reddit->_get_subreddits($comic, 'English')]);
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
    my $comic = MockComic::make_comic($MockComic::JSON => $json);

	is_deeply(['/r/comics', 'heimbrauen'], [$reddit->_get_subreddits($comic, 'Deutsch')]);
	is_deeply(['/r/comics', 'homebrewing'], [$reddit->_get_subreddits($comic, 'English')]);
}


sub subreddit_from_meta_data_scalar : Tests {
    my $json = <<'JSON';
            "reddit": {
                "use-default": false,
                "English": {
                    "subreddit": "foo"
                }
            }
JSON
    my $comic = MockComic::make_comic($MockComic::JSON => $json);

	is_deeply([], [$reddit->_get_subreddits($comic, 'Deutsch')]);
	is_deeply(['foo'], [$reddit->_get_subreddits($comic, 'English')]);
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
    my $comic = MockComic::make_comic($MockComic::JSON => $json);

	is_deeply([], [$reddit->_get_subreddits($comic, 'Deutsch')]);
	is_deeply(['foo', 'bar', 'baz'], [$reddit->_get_subreddits($comic, 'English')]);
}


sub ignores_empty_subreddits : Tests {
    my $json = '"reddit": { "English": { "subreddit": [ "" ] } }';
    my $comic = MockComic::make_comic($MockComic::JSON => $json);

    $reddit = Comic::Social::Reddit->new({
        'Reddit' => {
            'username' => 'me',
            'password' => 'pass',
            'client_id' => 'client',
            'secret' => 'very secret',
        },
    });

	is_deeply([], [$reddit->_get_subreddits($comic, 'English')]);
}


sub post : Tests {
    my $subreddit;
    my $title;
    my $url;
    my $got_link;

    no warnings qw/redefine/;
    local *Reddit::Client::submit_link = sub {
        my ($self, %args) = @_;
        $subreddit = $args{"subreddit"};
        $title = $args{"title"};
        $url = $args{"url"};
        return "redditID1234";
    };
    local *Reddit::Client::get_link = sub {
        my ($self, $link) = @_;
        $got_link = $link;
        return {"permalink" => "https://..."};
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "make beer" }
    );
    $comic->{url}{$MockComic::ENGLISH} = 'https://beercomics.com/comics/make-beer.html';
    my $message = $reddit->post($comic);
    is("Posted '[OC] make beer' (https://beercomics.com/comics/make-beer.html) to comics (redditID1234) at https://...",
        $message, "wrong message");
    is($subreddit, "comics", "wrong subreddit");
    is($title, "[OC] make beer", "wrong title");
    is($url, "https://beercomics.com/comics/make-beer.html", "wrong url");
    is($got_link, "redditID1234", "tried to get wrong link");
}


sub slows_down_posting : Tests {
    my $slowed = 0;
    my $slept;

    no warnings qw/redefine/;
    local *Reddit::Client::submit_link = sub {
        my ($self, %args) = @_;
        if (!$slowed) {
            $slowed = 1;
            die("you are posting too fast, try again in 1 second");
        }
        return "redditID1234";
    };
    local *Reddit::Client::get_link = sub {
        my ($self, $link) = @_;
        return {"permalink" => "https://..."};
    };
    local *Comic::Social::Reddit::_sleep = sub {
        ($slept) = @_;
        return;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "make beer" }
    );
    $comic->{url}{$MockComic::ENGLISH} = 'https://beercomics.com/comics/make-beer.html';
    my $message = $reddit->post($comic);

    is($slowed, 1, "should have slowed down");
    is($slept, 1, "should have slept for 1 second");
}


sub keeps_posting_if_already_posted : Tests {
    my @subreddits;

    no warnings qw/redefine/;
    local *Reddit::Client::submit_link = sub {
        my ($self, %args) = @_;
        push @subreddits, $args{"subreddit"};
        die "Already been submitted";
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "make beer" }
    );
    my $message = $reddit->post($comic);

    like($message, qr{already been submitted}i, "should have repoerted the error");
    is_deeply(\@subreddits, [ "comics" ]);
}


sub normalize_subreddit : Tests {
    is("funny", Comic::Social::Reddit::_normalize_subreddit("funny"));
    is("funny", Comic::Social::Reddit::_normalize_subreddit("funny/"));
    is("funny", Comic::Social::Reddit::_normalize_subreddit("/r/funny"));
    is("funny", Comic::Social::Reddit::_normalize_subreddit("/r/funny/"));
}


sub wait_for_limit : Tests {
    my $slept;

    no warnings qw/redefine/;
    local *Comic::Social::Reddit::_sleep = sub {
        $slept = shift @_;
        return;
    };
    use warnings;

    Comic::Social::Reddit::_wait_for_reddit_limit(undef, "try again in 10 minutes");
    is($slept, 10 * 60, "wrong 10 minutes sleep time");
    Comic::Social::Reddit::_wait_for_reddit_limit(undef, "try again in 1 minute");
    is($slept, 1 * 60, "wrong 1 minute sleep time");
    Comic::Social::Reddit::_wait_for_reddit_limit(undef, "try again in 20 seconds");
    is($slept, 20, "wrong 20 seconds sleep time");
    Comic::Social::Reddit::_wait_for_reddit_limit(undef, "try again in 1 second");
    is($slept, 1, "wrong 1 second sleep time");
}


sub wait_for_limit_already_submitted : Tests {
    my $comic = MockComic::make_comic();

    my $err = Comic::Social::Reddit::_wait_for_reddit_limit($comic, "That link has already been submitted\n");
    is($err, "That link has already been submitted");
}


sub wait_for_limit_unknown_error : Tests {
    my $comic = MockComic::make_comic();

    my $message = Comic::Social::Reddit::_wait_for_reddit_limit($comic, "500 internal server error");

    like($message, qr{\bdon't know\b}i, "Error message missing");
    like($message, qr{\b500 internal server error\b}, "original error message missing");
}


sub wait_for_limit_no_error : Tests {
    my $comic = MockComic::make_comic();

    my $message = Comic::Social::Reddit::_wait_for_reddit_limit($comic, "");
    is($message, "");
}
