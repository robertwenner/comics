use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;


__PACKAGE__->runtests() unless caller;


package TestTwitterStatus {
    use base 'Net::Twitter::Error';

    sub new {
        my ($class) = @_;
        my $self = bless{}, $class;
        $self->{text} = 'all good';
        return $self;
    }
}


my $twitter;
my %twitter_args;
my $twitter_status;


sub capture_args {
    my ($for, $comic, @args) = @_;
    $twitter_args{$for} = [@args];
    return $twitter_status;
}


sub set_up : Test(setup) {
    MockComic::set_up();

    %twitter_args = ();
    $twitter_status = TestTwitterStatus->new();
    $twitter = Test::MockModule->new(ref(Net::Twitter->new(traits => [qw/API::RESTv1_1/])));
    $twitter->redefine('update', sub {
        return capture_args('update', @_);
    });
    $twitter->redefine('update_with_media', sub {
        return capture_args('update_with_media', @_);
    });
}


sub complains_about_bad_mode : Tests {
    eval {
        Comic::_tweet(MockComic::make_comic(), 'English', mode => 'whatever');
    };
    like($@, qr(Unknown twitter mode 'whatever'));
}


sub tweet_png : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    Comic::_tweet($comic, 'English', mode => 'png');
    is_deeply([@{$twitter_args{'update_with_media'}}],
        ['This is the latest beercomic!', ['generated/english/web/comics/latest-comic.png']]);
    is($twitter_args{'update'}, undef);
}


sub tweet_html : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'This is the latest beercomic!' },
    );
    Comic::_tweet($comic, 'English', mode => 'html');
    is_deeply([@{$twitter_args{'update'}}], ['https://beercomics.com/comics/latest-comic.html']);
    is($twitter_args{'update_with_media'}, undef);
}



sub shortens_text : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'x' x 290 },
    );
    Comic::_tweet($comic, 'English', mode => 'png');
    is_deeply([@{$twitter_args{'update_with_media'}}],
        ['x' x 280, ['generated/english/web/comics/latest-comic.png']]);
}


sub hashtags_from_meta : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Funny stuff' },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#beer', '#craftbeer', '@you'] },
    );
    Comic::_tweet($comic, 'English', mode => 'png');
    is_deeply([@{$twitter_args{'update_with_media'}}],
        ['#beer #craftbeer @you Funny stuff', ['generated/english/web/comics/latest-comic.png']]);
}
