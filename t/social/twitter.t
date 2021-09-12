use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;

use Carp;
use HTTP::Response;
use Comic::Social::Twitter;


__PACKAGE__->runtests() unless caller;

my $twitter;
my %twitter_args;
my $twitter_error;


sub set_up : Test(setup) {
    MockComic::set_up();

    %twitter_args = ();
    $twitter_error = undef;

    $twitter = Test::MockModule->new(ref(Net::Twitter->new(traits => [qw/API::RESTv1_1/])));
    $twitter->redefine('update', sub {
        if ($twitter_error) {
            croak $twitter_error;
        }
        shift @_;
        $twitter_args{'update'} = [@_];
        return { text => "" };
    });
    $twitter->redefine('update_with_media', sub {
        shift @_;
        $twitter_args{'update_with_media'} = [@_];
        return { text => "" };
    });
}


sub accepts_good_modes : Tests {
    Comic::Social::Twitter->new(mode => 'png');
    Comic::Social::Twitter->new(mode => 'html');
    Comic::Social::Twitter->new();
    ok(1);
}


sub complains_about_bad_mode : Tests {
    eval {
        Comic::Social::Twitter->new(mode => 'whatever');
    };
    like($@, qr(Unknown twitter mode 'whatever'));
}


sub tweet_png : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    my $cs_twitter = Comic::Social::Twitter->new(mode => 'png');
    $cs_twitter->post($comic);
    is_deeply([@{$twitter_args{'update_with_media'}}],
        ['This is the latest beercomic!', ['generated/web/english/comics/latest-comic.png']]);
    is($twitter_args{'update'}, undef);
}


sub tweet_html : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    my $cs_twitter = Comic::Social::Twitter->new(mode => 'html');
    $cs_twitter->post($comic);
    is_deeply([@{$twitter_args{'update'}}], ['https://beercomics.com/comics/latest-comic.html']);
    is($twitter_args{'update_with_media'}, undef);
}


sub shortens_text : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'x' x 290 },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    my $cs_twitter = Comic::Social::Twitter->new();
    $cs_twitter->post($comic);
    is_deeply([@{$twitter_args{'update_with_media'}}],
        ['x' x 280, ['generated/web/english/comics/latest-comic.png']]);
}


sub hashtags_from_meta : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'] },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    my $cs_twitter = Comic::Social::Twitter->new();
    $cs_twitter->post($comic);
    is_deeply([@{$twitter_args{'update_with_media'}}],
        ['#beer #craftbeer @you Funny stuff', ['generated/web/english/comics/latest-comic.png']]);
}


sub handles_other_object_error : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    $twitter_error = bless {};
    my $cs_twitter = Comic::Social::Twitter->new(mode => 'html');

    my $message = $cs_twitter->post($comic);
    like($message, qr{\btwitter\b}i);
    like($message, qr{\bmain\b});
}


sub handles_non_twitter_error : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );

    $comic->{pngFile}{'English'} = "latest-comic.png";
    $twitter_error = "Oops";
    my $cs_twitter = Comic::Social::Twitter->new(mode => 'html');

    my $message = $cs_twitter->post($comic);
    like($message, qr{\btwitter\b}i);
    like($message, qr{\bOops\b});
}


sub handles_twitter_error : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    my $response = HTTP::Response->new(500, 'go away');
    $twitter_error = Net::Twitter::Error->new(http_response => $response);
    my $cs_twitter = Comic::Social::Twitter->new(mode => 'html');

    my $message = $cs_twitter->post($comic);

    like($message, qr{\b500\b}, 'error code missing');
    like($message, qr{\bgo away\b}, 'error message missing');
}
