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
    $reddit = Test::MockModule->new('Reddit::Client');
    $reddit->redefine('submit_link', sub {
        my ($comic, @args) = @_;
        %reddit_args = @args;
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


sub post_to_reddit_retries_on_rate_limit : Tests {
    my $slept;
    no warnings qw/redefine/;
    local *Comic::_sleep = sub {
        $slept = $_[0];
    };
    use warnings;

    my $comic = MockComic::make_comic();

    Comic::_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 1 minute.');
    is($slept, 60);

    Comic::_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 9 minutes.');
    is($slept, 60 * 9);

    Comic::_wait_for_reddit_limit('Error(s): [RATELIMIT] you are doing that too much. try again in 10 seconds.');
    is($slept, 10);

    eval {
        Comic::_wait_for_reddit_limit('Error(s): whatever');
    };
    like($@, qr{Don't know what reddit complains about}i);
}