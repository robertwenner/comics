use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;

use Comic::Social::Mastodon;

use Mastodon::Entity::Account;
use Mastodon::Entity::Attachment;
use Mastodon::Entity::Status;


__PACKAGE__->runtests() unless caller;

my %secrets;
my $mastodon;
my @mastodon_error;
my $mastodon_latest;
my %mastodon_called_with;
my $mastodon_return_upload_media;
my $mastodon_return_post_status;


sub set_up : Test(setup) {
    MockComic::set_up();

    %secrets = (
        'client_key' => 'key',
        'client_secret' => 'secret',
        'access_token' => 'token',
    );

    %mastodon_called_with = ();
    @mastodon_error = ();
    $mastodon_latest = undef;

    $mastodon = Test::MockModule->new('Mastodon::Client');
    $mastodon->redefine('new', sub {
        my $mast = $mastodon->original('new')->(@_);
        shift @_;
        $mastodon_called_with{'new'} = {@_};
        return $mast;
    });
    $mastodon->redefine('upload_media', sub {
        shift @_;
        $mastodon_called_with{'upload_media'} = [@_];
        return $mastodon_return_upload_media;
    });
    $mastodon->redefine('post_status', sub {
        shift @_;
        $mastodon_called_with{'post_status'} = [@_];
        my $should_fail = pop @mastodon_error;
        die($should_fail) if ($should_fail);
        return $mastodon_return_post_status;
    });
    $mastodon->redefine('latest_response', sub {
        return $mastodon_latest;
    });
}


sub fails_on_missing_configuration : Tests {
    eval {
        Comic::Social::Mastodon->new();
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(configuration missing)i, 'should say what is wrong');

    eval {
        Comic::Social::Mastodon->new(
            'client_key' => 'key',
            'access_token' => 'token',
        );
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(client_secret missing)i, 'should say what is wrong');

    eval {
        Comic::Social::Mastodon->new(
            'client_secret' => 'secret',
            'access_token' => 'token',
        );
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(client_key missing)i, 'should say what is wrong');

    eval {
        Comic::Social::Mastodon->new(
            'client_key' => 'me',
            'client_secret' => 'secret',
        );
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(access_token missing)i, 'should say what is wrong');
}


sub accepts_good_modes : Tests {
    Comic::Social::Mastodon->new(%secrets, mode => 'png');
    Comic::Social::Mastodon->new(%secrets, mode => 'html');
    Comic::Social::Mastodon->new(%secrets);
    ok(1);
}


sub complains_about_bad_mode : Tests {
    eval {
        Comic::Social::Mastodon->new(%secrets, 'mode' => 'whatever');
    };
    like($@, qr(Unknown mastodon mode 'whatever')i);
}


sub passes_config_to_mastodon_client : Tests {
    Comic::Social::Mastodon->new(%secrets, 'instance' => 'my mastodon', 'mode' => 'png');
    is_deeply(
        $mastodon_called_with{'new'},
        {
            'client_id' => 'key',
            'client_secret' => 'secret',
            'access_token' => 'token',
            'instance' => 'my mastodon',
            'name' => 'Comic::Social::Mastodon 0.0.3',
            'website' => 'https://github.com/robertwenner/comics',
            'coerce_entities' => 1,
        });
}


sub complains_about_manually_specified_client_id : Tests {
    eval {
        Comic::Social::Mastodon->new(%secrets, 'client_id' => 'id');
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(\bclient_id\b)i, 'should say what is wrong');
    like($@, qr(\bclient_key\b)i, 'should say how to configure this instead');
}


sub toot_html : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{'English'} = "https://beercomics.com/comics/latest-comic.html";
    $mastodon_return_post_status = Mastodon::Entity::Status->new(
        'account' => Mastodon::Entity::Account->new('acct' => 'my-account', 'avatar' => 'my-avatar'),
        'favourites_count' => 0,
        'content' => 'tooted html fine',
        'visibility' => 'public',
    );

    my $mastodon = Comic::Social::Mastodon->new(%secrets, 'mode' => 'html');
    my $results = $mastodon->post($comic);

    is($results, 'Comic::Social::Mastodon posted: tooted html fine');
    is($mastodon_called_with{'update_with_media'}, undef);
    is_deeply(
        $mastodon_called_with{'post_status'},
        ["Latest comic\nhttps://beercomics.com/comics/latest-comic.html", {}]);
}


sub toot_png : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    $mastodon_return_upload_media = Mastodon::Entity::Attachment->new(
        'id' => '123',
        'type' => 'image',
        'url' => 'https://beercomics.com/comics/latest-comic.png',
        'preview_url' => 'https://beercomics.com/comics/latest-comic.png',
    );
    $mastodon_return_post_status = Mastodon::Entity::Status->new(
        'account' => Mastodon::Entity::Account->new('acct' => 'my-account', 'avatar' => 'my-avatar'),
        'favourites_count' => 0,
        'content' => 'tooted png fine',
        'visibility' => 'public',
    );

    my $mastodon = Comic::Social::Mastodon->new(%secrets, 'mode' => 'png');
    my $results = $mastodon->post($comic);

    is_deeply($results, 'Comic::Social::Mastodon posted: tooted png fine');
    is_deeply(
        $mastodon_called_with{'upload_media'},
        ['generated/web/english/comics/latest-comic.png', {'description' => 'Latest comic'}]);
    is_deeply(
        $mastodon_called_with{'post_status'},
        ['Latest comic', {'media_ids' => [123]}]);
}


sub shortens_tooted_text : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'x' x 1000 },
    );
    $mastodon_return_post_status = Mastodon::Entity::Status->new(
        'account' => Mastodon::Entity::Account->new('acct' => 'my-account', 'avatar' => 'my-avatar'),
        'favourites_count' => 0,
        'content' => 'tooted html fine',
        'visibility' => 'public',
    );

    my $mastodon = Comic::Social::Mastodon->new(%secrets, 'mode' => 'html');
    $mastodon->post($comic);

    my $text = $mastodon_called_with{'post_status'}[0];
    is(length($text), 524);
    like($text, qr{Latest comic}, 'title not posted');
    like($text, qr{\bxxxxx}, 'description not posted');
    like($text, qr{\bhttps://beercomics.com/comics/latest-comic.html\b}, 'link not posted');
}


sub includes_hashtags_from_comic_meta_data : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::HASH_TAGS => { $MockComic::ENGLISH => ['#general'] },
        $MockComic::MASTODON => { $MockComic::ENGLISH => ['@mastodon'] },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#ignore'] },
    );
    $mastodon_return_post_status = Mastodon::Entity::Status->new(
        'account' => Mastodon::Entity::Account->new('acct' => 'my-account', 'avatar' => 'my-avatar'),
        'favourites_count' => 0,
        'content' => 'tooted html fine',
        'visibility' => 'public',
    );

    my $mastodon = Comic::Social::Mastodon->new(%secrets, mode => 'html');
    $mastodon->post($comic);

    is_deeply(
        $mastodon_called_with{'post_status'},
        ["Latest comic\n#general \@mastodon\nhttps://beercomics.com/comics/latest-comic.html", {}]);
}


sub reports_error_no_latest_from_mastodon : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    push @mastodon_error, "Oops";

    my $mastodon = Comic::Social::Mastodon->new(%secrets, mode => 'html');
    my $message = $mastodon->post($comic);

    like($message, qr{\bmastodon\b}i, 'should say what module had the error');
    like($message, qr{\bOops\b}, 'should have error message');
}


sub reports_error_with_latest_string_from_mastodon : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    push @mastodon_error, "Oops";
    $mastodon_latest = "latest mastodon details";

    my $mastodon = Comic::Social::Mastodon->new(%secrets, mode => 'html');
    my $message = $mastodon->post($comic);

    like($message, qr{\bmastodon\b}i, 'should say what module had the error');
    like($message, qr{latest mastodon details}i, 'should have error details');
}


sub reports_error_latest_http_response_from_mastodon : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    push @mastodon_error, "Oops";
    $mastodon_latest = HTTP::Response->new(
        401, "Unauthorized", undef, "error body"
    );

    my $mastodon = Comic::Social::Mastodon->new(%secrets, mode => 'html');
    my $message = $mastodon->post($comic);

    like($message, qr{\bmastodon\b}i, 'should say what module had the error');
    like($message, qr{\b401 Unauthorized\b}, 'should have http error line');
    like($message, qr{\berror body\b}, 'should have http content');
}


sub rejects_bad_retry400_argument : Tests {
    eval {
        Comic::Social::Mastodon->new(%secrets, retry400 => 'yes!');
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(retry400)i, 'should mention the argument');
    like($@, qr(\bnumber\b)i, 'should say what is wrong');
}


sub logs_400_and_retries_if_configured_till_it_succeeds : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    push @mastodon_error, "Oops";
    $mastodon_latest = HTTP::Response->new(
        400, "Bad Request", undef, "error body"
    );

    my $mastodon = Comic::Social::Mastodon->new(%secrets, mode => 'html', retry400 => 1);
    my $message = $mastodon->post($comic);

    like($message, qr{\bmastodon\b}i, 'should say what module had the error');
    like($message, qr{\b400 Bad Request\b}, 'should have http error line');
    like($message, qr{\berror body\b}, 'should have http content');
    like($message, qr{\bRetry 1 of 1\b}m, 'should say it is retrying');
    like($message, qr{\btooted\b}m, 'should have said it worked');
    ok($message !~ m{\bRetry 2\b}m, 'should not have retried again');
}


sub logs_400_and_retries_if_configured_till_max_retries : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    push @mastodon_error, ("Oops", "still not", "nope", "no dice today");
    $mastodon_latest = HTTP::Response->new(
        400, "Bad Request", undef, "error body"
    );

    my $mastodon = Comic::Social::Mastodon->new(%secrets, mode => 'html', retry400 => 3);
    my $message = $mastodon->post($comic);

    like($message, qr{\bmastodon\b}i, 'should say what module had the error');
    like($message, qr{\b400 Bad Request\b}, 'should have http error line');
    like($message, qr{\berror body\b}, 'should have http content');
    like($message, qr{\bRetry 1 of 3\b}m, 'should say it is retrying');
    like($message, qr{\bRetry 2 of 3\b}m, 'should say it is retrying');
    like($message, qr{\bRetry 3 of 3\b}m, 'should say it is retrying');
    ok($message !~ m{\bRetry 4\b}m, 'should not have retried again');
    ok($message !~ m{\btooted\b}m, 'should not say it tooted');
}
