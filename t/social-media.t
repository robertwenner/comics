use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


my $file;
my $desc;


sub set_up : Test(setup) {
    MockComic::set_up();

    no warnings qw/redefine/;
    *Comic::_tweet = sub {
        ($file, $desc) = @_;
    };
    use warnings;
}


sub tweets : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    Comic::post_to_social_media('English');
    is($file, 'generated/english/web/comics/latest-comic.png');
    is($desc, 'This is the latest beercomic!');
}


sub shortens_twitter_text : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'x' x 150 },
    );
    Comic::post_to_social_media('English');
    is($desc, 'x' x 130);
}


sub hashtags : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'] },
    );
    Comic::post_to_social_media('English');
    is($desc, '#beer #craftbeer @you Funny stuff');
}
