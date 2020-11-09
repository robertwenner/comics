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


sub passes_options : Tests {
    my %twitter;
    my %reddit;

    no warnings qw/redefine/;
    local *Comic::Social::Twitter::new = sub {
        my ($self, %args) = @_;
        %twitter = %args;
    };
    local *Comic::Social::Reddit::new = sub {
        my ($self, %args) = @_;
        %reddit = %args;
    };
    use warnings;

    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => "2000-01-01");
    eval {
        Comic::post_to_social_media(
            twitter => {
                mode => 'png'
            },
            reddit => {
                secret => 'me',
            }
        );
    };
    # Ignore eval error about not posting cause the comic is not current
    is_deeply(\%twitter, {mode => 'png'}, 'wrong twitter settings');
    is_deeply(\%reddit, {secret => 'me'}, 'wrong reddit settings');
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


sub posts_comic : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Latest comic',
            $MockComic::DEUTSCH => 'Neustes Comic',
        },
    );

    my @tweeted;
    my @posted;

    no warnings qw/redefine/;
    local *Comic::Social::Twitter::tweet = sub {
        my ($self, $comic) = @_;
        push @tweeted, $comic;
    };
    local *Comic::Social::Reddit::post = sub {
        my ($self, $comic, @subreddits) = @_;
        push @posted, $comic;
    };
    use warnings;

    Comic::post_to_social_media();
    is_deeply(\@tweeted, [$comic], 'tweeted wrong comic');
    is_deeply(\@posted, [$comic], 'posted  wrong comic');
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
    my @posted;

    no warnings qw/redefine/;
    local *Comic::Social::Twitter::tweet = sub {
        my ($self, $comic) = @_;
        push @tweeted, $comic;
    };
    local *Comic::Social::Reddit::post = sub {
        my ($self, $comic);
        push @posted, $comic;
        return '';
    };
    use warnings;

    Comic::post_to_social_media();
    is_deeply(\@tweeted, [$current2, $current1], 'Tweeted wrong comics');
}


sub multiple_comics_different_languages : Tests {
    my $de = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Neustes Comic' },
    );
    my $en = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    my @tweeted;
    my @posted;

    no warnings qw/redefine/;
    local *Comic::Social::Twitter::tweet = sub {
        my ($self, $comic) = @_;
        push @tweeted, $comic;
        return '';
    };
    local *Comic::Social::Reddit::post = sub {
        my ($self, $comic) = @_;
        push @posted, $comic;
        return '';
    };
    use warnings;

    Comic::post_to_social_media();
    is_deeply(\@tweeted, [$en, $de], 'Tweeted wrong comics');
    is_deeply(\@posted, [$en, $de], 'Posted wrong comics');
}
