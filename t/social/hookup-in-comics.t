use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;

use Comics;
use Comic::Settings;
use lib 't';
use MockComic;
use lib 't/social';
use DummySocialMedia;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));
}


sub load_social_media_modules_none_configured : Tests {
    my $comics = Comics->new();
    $comics->load_social_media_posters();
    is_deeply($comics->{'social_media_posters'}, []);
}


sub passes_options_to_constructor : Tests {
    my $comics = Comics->new();
    MockComic::fake_file('config.json',
        '{"' . $Comic::Settings::SOCIAL_MEDIA_POSTERS . '": {"DummySocialMedia": {"foo": "bar"}}}');
    $comics->load_settings('config.json');

    $comics->load_social_media_posters();

    my @social_media_posters = @{$comics->{'social_media_posters'}};
    is(@social_media_posters, 1, 'should have one SocialMediaPoster');
    $social_media_posters[0]->assert_constructed('foo', 'bar');
}


sub posts_comic : Tests {
    my $comics = Comics->new();
    my $social = DummySocialMedia->new();
    push @{$comics->{'social_media_posters'}}, $social;
    my $comic = MockComic::make_comic();

    my @msgs = $comics->post_to_social_media($comic);

    is_deeply([@msgs], ["posted to dummy\n"]);
    $social->assert_posted($comic);
}


sub no_comics : Tests {
    my $comics = Comics->new();
    my @msgs = $comics->post_todays_comic_to_social_media();
    like($msgs[0], qr(not posting)i, 'did complain');
    like($msgs[0], qr(no comics)i, 'gave reason');
}


sub no_new_comic : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));
    my $comics = Comics->new();
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-01');
    push @{$comics->{comics}}, $comic;
    my @msgs = $comics->post_todays_comic_to_social_media();
    like($msgs[0], qr(not posting)i, 'did complain');
    like($msgs[0], qr(not from today)i, 'gave reason');
}


sub one_comic_today : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));
    my $comics = Comics->new();

    my $social = DummySocialMedia->new();
    push @{$comics->{'social_media_posters'}}, $social;

    my $old = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Old comic' },
        $MockComic::PUBLISHED_WHEN => '2010-01-01',
    );
    my $current = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::PUBLISHED_WHEN => '2016-08-01',
    );
    my $future = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Way too new comic' },
        $MockComic::PUBLISHED_WHEN => '2121-01-01',
    );
    push @{$comics->{comics}}, $old, $current, $future;

    $comics->post_todays_comic_to_social_media();

    $social->assert_posted($current);
}


sub multiple_comics_today_same_language : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));
    my $comics = Comics->new();

    my $social = DummySocialMedia->new();
    push @{$comics->{'social_media_posters'}}, $social;

    my $old = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Old comic' },
        $MockComic::PUBLISHED_WHEN => '2010-01-01',
    );
    my $current1 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::PUBLISHED_WHEN => '2016-08-01',
    );
    my $current2 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Also latest comic' },
        $MockComic::PUBLISHED_WHEN => '2016-08-01',
    );
    my $future = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Way too new comic' },
        $MockComic::PUBLISHED_WHEN => '2121-01-01',
    );
    push @{$comics->{comics}}, $old, $current1, $current2, $future;

    $comics->post_todays_comic_to_social_media();

    $social->assert_posted($current1, $current2);
}


sub multiple_comics_today_different_languages : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 1));
    my $comics = Comics->new();

    my $social = DummySocialMedia->new();
    push @{$comics->{'social_media_posters'}}, $social;

    my $de = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Neustes Comic' },
    );
    my $en = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    push @{$comics->{comics}}, $de, $en;

    $comics->post_todays_comic_to_social_media();

    $social->assert_posted($de, $en);
}
