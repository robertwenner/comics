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


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));

    no warnings qw/redefine/;
    *Comic::_tweet = sub {
        my ($file, $language, $desc) = @_;
        $file{$language} = $file;
        $desc{$language} = $desc;
    };
    use warnings;

    %file = ();
    %desc = ();
}


sub tweets : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    Comic::post_to_social_media('English');
    is($file{$MockComic::ENGLISH}, 'generated/english/web/comics/latest-comic.png');
    is($desc{$MockComic::ENGLISH}, 'This is the latest beercomic!');
}


sub shortens_twitter_text : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'x' x 150 },
    );
    Comic::post_to_social_media('English');
    is($desc{$MockComic::ENGLISH}, 'x' x 130);
}


sub hashtags : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'] },
    );
    Comic::post_to_social_media('English');
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
    Comic::post_to_social_media($MockComic::ENGLISH, $MockComic::DEUTSCH);
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
    Comic::post_to_social_media();
    is($desc{$MockComic::ENGLISH}, '#beer #craftbeer @you Funny stuff');
    is($desc{$MockComic::DEUTSCH}, '#Bier #selbstbrauen @duda Lustiges Bier');
    is($desc{$MockComic::ESPAÑOL}, undef);
}


sub test_resets_comics : Tests {
    # Makes I don't forget to clear the %desc and %file hashes between tests.
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
    is(Comic::post_to_social_media(), 1, 'wrong return code');
    is($desc{$MockComic::ENGLISH}, undef);
}

__END__
sub toots : Tests {
}
