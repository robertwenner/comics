use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use Test::MockModule;
use JSON;

use lib 't';
use MockComic;

use Comic::Social::IndexNow;


__PACKAGE__->runtests() unless caller;

my @posted;
my $reply;


sub mocked_replies {
    my ($self, $url, $options) = @_;

    is($url, 'https://api.indexnow.org/indexnow', 'posted to wrong URL');
    is_deeply($options->{headers}, { 'Content-Type' => 'application/json; charset=utf-8' }, 'posted wrong headers');
    push @posted, decode_json($options->{content});

    return $reply;
}


sub set_up : Test(setup) {
    MockComic::set_up();

    @posted = ();
    $reply = {
        'success' => 1,
        'status' => 200,
        'reason' => 'Ok',
    };
}


sub complains_about_missing_args : Tests {
    eval {
        Comic::Social::IndexNow->new();
    };
    like($@, qr{Comic::Social::IndexNow}, 'should mention module');
    like($@, qr{\bmissing\b}, 'should say what is wrong');
    like($@, qr{\bsettings\b}, 'should say what argument was expected');

    eval {
        Comic::Social::IndexNow->new('foo');
    };
    like($@, qr{\bhash\b}, 'should say what is wrong');
    like($@, qr{\bsettings\b}, 'should say what argument was expected');

    eval {
        Comic::Social::IndexNow->new('url' => 'https://indexnow.org/indexnow');
    };
    like($@, qr{\bkey\b}, 'should say what argument was missing');
    like($@, qr{missing}, 'should say what is wrong');

    eval {
        Comic::Social::IndexNow->new('key' => '');
    };
    like($@, qr{\bkey\b}, 'should say what argument was missing');
    like($@, qr{missing}, 'should say what is wrong');
}


sub complains_about_bad_key : Tests {
    eval {
        Comic::Social::IndexNow->new('key' => '12345');
    };
    like($@, qr{\bkey\b}, 'should say what argument was bad');
    like($@, qr{too short}, 'should say what is wrong');

    eval {
        Comic::Social::IndexNow->new('key' => 'x' x 129);
    };
    like($@, qr{\bkey\b}, 'should say what argument was bad');
    like($@, qr{too long}, 'should say what is wrong');

    eval {
        Comic::Social::IndexNow->new('key' => '!@#$%^&*()');
    };
    like($@, qr{\bkey\b}, 'should say what argument was bad');
    like($@, qr{characters}, 'should say what is wrong');

    eval {
        Comic::Social::IndexNow->new('key' => 'Motörhead');
    };
    like($@, qr{\bkey\b}, 'should say what argument was bad');
    like($@, qr{characters}, 'should say what is wrong');
}


sub complains_about_bad_url : Tests {
    eval {
        Comic::Social::IndexNow->new('key' => '12345678', 'url' => 'indexnow.org/indexnow?url=here');
    };
    like($@, qr{\burl\b}, 'should say what argument was bad');
    like($@, qr{query string}, 'should say what is wrong');
}


sub accepts_good_params : Tests {
    eval {
        Comic::Social::IndexNow->new('key' => 'a-zA-Z123456789-', url => 'https://indexnow.org/indexnow');
    };
    is($@, '');
}


sub adds_https_to_url : Tests {
    my $no_protocol = Comic::Social::IndexNow->new('key' => '12345678', 'url' => 'indexnow.org');
    is($no_protocol->{settings}{url}, 'https://indexnow.org');

    my $with_protocol = Comic::Social::IndexNow->new('key' => '12345678', 'url' => 'http://indexnow.org');
    is($with_protocol->{settings}{url}, 'http://indexnow.org');
}


sub posts_one_comic : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Latest comic',
            $MockComic::DEUTSCH => 'Neustes Comic',
        },
    );

    my $index_now = Comic::Social::IndexNow->new('key' => '12345678');
    $index_now->post($comic);

    is_deeply(\@posted, [
        { key => '12345678', host => 'biercomics.de', urlList => ['https://biercomics.de/comics/neustes-comic.html'] },
        { key => '12345678', host => 'beercomics.com', urlList => ['https://beercomics.com/comics/latest-comic.html'] },
    ]);
}


sub posts_many_comics : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post', \&mocked_replies);

    my $de = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Neustes Comic',
        },
    );
    my $en = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Latest comic',
        },
    );

    my $index_now = Comic::Social::IndexNow->new('key' => '12345678');
    $index_now->post($de, $en);

    is_deeply(\@posted, [
        { key => '12345678', host => 'biercomics.de', urlList => ['https://biercomics.de/comics/neustes-comic.html'] },
        { key => '12345678', host => 'beercomics.com', urlList => ['https://beercomics.com/comics/latest-comic.html'] },
    ]);
}


sub returns_indexnow_reply : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Latest comic',
        },
    );

    my $index_now = Comic::Social::IndexNow->new('key' => '12345678');
    my @messages = $index_now->post($comic);

    is_deeply(\@messages, [
        'Comic::Social::IndexNow: submitting https://beercomics.com/comics/latest-comic.html',
        'Comic::Social::IndexNow: 200 Ok',
    ]);
}
