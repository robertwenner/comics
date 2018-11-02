use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;


__PACKAGE__->runtests() unless caller;


my $reddit;
my %reddit_args;


sub set_up : Test(setup) {
    MockComic::set_up();

    %reddit_args = ();
    my $reddit_full_name;
    $reddit = Test::MockModule->new('Reddit::Client');
    $reddit->redefine('submit_link', sub {
        my ($r, @args) = @_;
        %reddit_args = @args;
    });
    $reddit->redefine('get_link', sub {
        my ($r, $full_name) = @_;
        $reddit_full_name = $full_name;
        my $link = Reddit::Client::Link->new();
        $link->{permalink} = '/r/comics/reddit-test';
        return $link;
    });
}


sub adds_oc_tag_and_subreddit : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    Comic::_reddit($comic, 'English', ());
    is($reddit_args{'title'}, '[OC] Latest comic');
    is($reddit_args{'url'}, 'https://beercomics.com/comics/latest-comic.html');
    is($reddit_args{'subreddit'}, 'comics');
}


sub override_subreddit : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    Comic::_reddit($comic, 'English', (subreddit => 'beer'));
    is($reddit_args{'subreddit'}, 'beer');
}


sub strips_r_slash_from_subreddit : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    my $log = Comic::_reddit($comic, 'English', (subreddit => '/r/beer/'));
    is($reddit_args{'subreddit'}, 'beer');
}


sub post_to_reddit_retries_on_rate_limit : Tests {
    my $slept;
    no warnings qw/redefine/;
    local *Comic::_sleep = sub {
        $slept = $_[0];
    };
    use warnings;

    my $comic = MockComic::make_comic();

    $comic->_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 1 minute.');
    is($slept, 60);

    $comic->_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 9 minutes.');
    is($slept, 60 * 9);

    $comic->_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 10 seconds.');
    is($slept, 10);

    $comic->_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 1 second.');
    is($slept, 1);

    eval {
        $comic->_wait_for_reddit_limit('Error(s): whatever');
    };
    like($@, qr{Don't know what reddit complains about}i);
    like($@, qr{whatever}i);
}


sub gets_url_for_full_name : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    my $log = Comic::_reddit($comic, 'English', (subreddit => 'beer'));
    like($log, qr{/r/comics/reddit-test});
}


sub already_submitted_doesnt_fail_script : Tests {
    my $reddit = Test::MockModule->new('Reddit::Client');
    $reddit->redefine('submit_link', sub {
        my ($r, @args) = @_;
        die "[ALREADY_SUB] that link has already been submitted";
    });
    my $comic = MockComic::make_comic();
    my $log;
    eval {
        $log = $comic->_reddit('English');
    };
    is($@, '');
    like($log, qr{has already been submitted}, 'has actual error message');
    like($log, qr{\bcomics\b}, 'includes subreddit');
    like($log, qr{\bEnglish\b}, 'includes language');
}


sub no_full_name : Tests {
    my $reddit = Test::MockModule->new('Reddit::Client');
    $reddit->redefine('submit_link', sub {
        return undef;
    });
    my $comic = MockComic::make_comic();
    my $log;
    eval {
        $log = $comic->_reddit('English');
    };
    is($@, '');
    like($log, qr{Posted});
}
