use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use Capture::Tiny;
use lib 't';
use MockComic;

use JSON;
use Comic::Social::Mastodon;


__PACKAGE__->runtests() unless caller;


my %settings;
my %media_reply;
my %media_reply_payload;
my %status_reply;
my %status_reply_payload;
my @posted;


sub set_up : Test(setup) {
    MockComic::set_up();

    %settings = (
        'instance' => 'mastodon.example.org',
        'access_token' => 'my-token',
        'mode' => 'html',
    );

    %media_reply_payload = (
        'id' => 'returned media id',
        'type' => 'returned type',
        'description' => 'returned description',
    );
    %media_reply = (
        'content' => encode_json(\%media_reply_payload),
        'status' => 200,
        'success' => 'OK',
    );

    %status_reply_payload = (
        'id' => 'returned status id',
        'created_at' => 'returned time stamp',
        'language' => 'returned language code',
        'content' => 'returned content',
    );
    %status_reply = (
        'content' => encode_json(\%status_reply_payload),
        'status' => 200,
        'success' => 'OK',
    );

    @posted = ();
}


sub mocked_replies {
    my ($self, $url, $form_data, $options) = @_;

    push @posted, { 'url' => $url, 'form_data' => $form_data };

    is_deeply($options, {
        'headers' => { 'Authorization' => 'Bearer my-token' },
    }, 'should always pass the authorization header');

    if ($url =~ m{/api/v2/media}m) {
        return \%media_reply;
    }
    if ($url =~ m{/api/v1/statuses}m) {
        return \%status_reply;
    }
    die "Posted to unknown url $url";
}


sub complains_about_missing_configuration : Tests {
    eval {
        Comic::Social::Mastodon->new();
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(configuration missing)i, 'should say what is wrong');

    eval {
        Comic::Social::Mastodon->new(
            'instance' => 'i',
            'mode' => 'png',
        );
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(\baccess_token\b), 'should say what is missing');

    eval {
        Comic::Social::Mastodon->new(
            'access_token' => 'token',
            'mode' => 'png',
        );
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(\binstance\b), 'should say what is missing');

    eval {
        Comic::Social::Mastodon->new(
            'access_token' => 'token',
            'instance' => 'i',
        );
    };
    like($@, qr(Comic::Social::Mastodon)i, 'should say the module name');
    like($@, qr(\bmode\b), 'should say what is missing');
}


sub complains_about_bad_instance : Tests {
    eval {
        Comic::Social::Mastodon->new('instance' => 'https://mstd.example.org/my/account');
    };
    like($@, qr{Comic::Social::Mastodon}, 'should say the modulename');
    like($@, qr{\binstance\b}, 'should say the bad setting');
    like($@, qr{\bslash}i, 'should say what is wrong');
}


sub accepts_good_modes : Tests {
    Comic::Social::Mastodon->new(%settings, mode => 'png');
    Comic::Social::Mastodon->new(%settings, mode => 'html');
    Comic::Social::Mastodon->new(%settings);
    ok(1);  # would have died if it failed
}


sub complains_about_bad_mode : Tests {
    eval {
        Comic::Social::Mastodon->new(%settings, 'mode' => 'whatever');
    };
    like($@, qr{Comic::Social::Mastodon}, 'should say the modulename');
    like($@, qr{\bmode\b}, 'should say the bad setting');
    like($@, qr{\bwhatever\b}, 'should say the bad value');
}


sub toot_html : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{'English'} = "https://beercomics.com/comics/latest-comic.html";

    my $mastodon = Comic::Social::Mastodon->new(%settings, 'mode' => 'html');
    my $results = $mastodon->post($comic);

    is_deeply(\@posted, [
        {
            'url' => 'https://mastodon.example.org/api/v1/statuses',
            'form_data' => {
                status => "Latest comic\nhttps://beercomics.com/comics/latest-comic.html",
                language => 'en',
            },
        }
    ]);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\breturned language\b}, 'should have language code');
    like($results, qr{\breturned time stamp\b}, 'should have time stamp');
    like($results, qr{\breturned status id\b}, 'should have id');
    like($results, qr{\breturned content\b}, 'should have content');
}


sub toot_png : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %status_reply_payload = (
        %status_reply_payload,
        'media_attachments' => [
            {
                "id" => "returned attachment id",
                "type" => "returned type",
                "url" => "returned url",
            },
        ],
    );
    %status_reply = (
        %status_reply,
        'content' => encode_json(\%status_reply_payload),
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, 'mode' => 'png');
    my $results = $mastodon->post($comic);

    is_deeply(\@posted, [
        {
            'url' => 'https://mastodon.example.org/api/v2/media',
            'form_data' => {
                'description' => "Latest comic",
                'file' => 'png file contents',
            },
        },
        {
            'url' => 'https://mastodon.example.org/api/v1/statuses',
            'form_data' => {
                'status' => 'Latest comic',
                'language' => 'en',
                'media_ids[]' => 'returned media id',
            },
        },
    ]);

    like($results, qr{\bComic::Social::Mastodon\b}m, 'should contain module name');
    like($results, qr{\bmedia\b}, 'should say it posted media');
    like($results, qr{\breturned media id\b}, 'should have the returned image media id');

    like($results, qr{\breturned language\b}, 'should have language code');
    like($results, qr{\breturned time stamp\b}, 'should have time stamp');
    like($results, qr{\breturned status id\b}, 'should have id');
    like($results, qr{\breturned content\b}, 'should have content');
    like($results, qr{\breturned media id\b}, 'should have the attachment id');
}


sub ignores_empty_media_attachments_array : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %status_reply_payload = (
        %status_reply_payload,
        'media_attachments' => [],
    );
    %status_reply = (
        %status_reply,
        'content' => encode_json(\%status_reply_payload),
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, 'mode' => 'png');
    my $results = $mastodon->post($comic);

    unlike($results, qr{\breferring\b}, 'should not have the attachment id');
}


sub shortens_tooted_text : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'x' x 1000 },
    );

    my $mastodon = Comic::Social::Mastodon->new(%settings, 'mode' => 'html');
    $mastodon->post($comic);

    my $text = $posted[0]->{form_data}->{status};
    is(length($text), 524);
    like($text, qr{Latest comic}, 'title not posted');
    like($text, qr{\bxxxxx}, 'description not posted');
    like($text, qr{\bhttps://beercomics.com/comics/latest-comic.html\b}, 'link not posted');
}


sub includes_hashtags_from_comic_meta_data : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::HASH_TAGS => { $MockComic::ENGLISH => ['#general'] },
        $MockComic::MASTODON => { $MockComic::ENGLISH => ['@mastodon'] },
        $MockComic::TWITTER => { $MockComic::ENGLISH => ['#ignore'] },
    );

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'html');
    $mastodon->post($comic);

    my $text = $posted[0]->{form_data}->{status};
    is("Latest comic\n#general \@mastodon\nhttps://beercomics.com/comics/latest-comic.html", $text);
}


sub includes_visibility_if_configured : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{'English'} = "https://beercomics.com/comics/latest-comic.html";

    my $mastodon = Comic::Social::Mastodon->new(%settings, 'mode' => 'html', 'visibility' => 'private');
    my $results = $mastodon->post($comic);

    is_deeply(\@posted, [
        {
            'url' => 'https://mastodon.example.org/api/v1/statuses',
            'form_data' => {
                status => "Latest comic\nhttps://beercomics.com/comics/latest-comic.html",
                language => 'en',
                visibility => 'private',
            },
        }
    ]);
}


sub reports_missing_content_from_status_reply : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    delete $status_reply{'content'};

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'html');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bno content\b}, 'should not have content');
}


sub reports_error_if_content_from_status_reply_is_unparsable : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %status_reply = (
        %status_reply,
        'content' => 'whatever',
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'html');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bJSON\b}i, 'should say what was wrong');
}


sub uses_fallback_values_if_fields_from_status_reply_are_missing : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %status_reply = (
        %status_reply,
        'content' => '{}',
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'html');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bno id\b}, 'should not have content');
    like($results, qr{\bno language\b}, 'should not have content');
    like($results, qr{\bno timestamp\b}, 'should not have content');
    like($results, qr{\bno content\b}, 'should not have content');
}


sub reports_missing_content_from_media_reply : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    delete $media_reply{'content'};

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'png');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bno content\b}, 'should not have content');
    is(scalar @posted, 2, 'should still have made both API calls');
}


sub reports_error_if_content_from_media_reply_is_unparsable : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %media_reply = (
        %media_reply,
        'content' => 'whatever',
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'png');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bJSON\b}i, 'should say what was wrong');
}


sub falls_back_to_posting_a_link_if_media_post_fails : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %media_reply = (
        %media_reply,
        'content' => '{}',
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{'English'} = "https://beercomics.com/comics/latest-comic.html";
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'png');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bno media id\b}, 'should not have a media id');
    like($results, qr{\blink\b}, 'should say that it is falling back to posting a link');
    like($posted[1]->{form_data}->{'status'}, qr{https://beercomics\.com/comics/latest-comic\.html}, 'should have posted the link');
    is($posted[1]->{form_data}->{'media_ids[]'}, undef, 'should not have passed bad media id back');
}


sub reports_http_error_from_media_post : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %media_reply = (
        %status_reply,
        'success' => '',
        'status' => 500,
        'reason' => 'Internal server error',
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'png');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bHTTP 500\b}, 'should have error code');
    like($results, qr{\bInternal server error\b}, 'should have error message ');
}


sub reports_http_error_from_status_post : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %status_reply = (
        %status_reply,
        'success' => '',
        'status' => 500,
        'reason' => 'Internal server error',
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'html');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bHTTP 500\b}, 'should have error code');
    like($results, qr{\bInternal server error\b}, 'should have error message ');
}


sub reports_errors_unrelated_to_mastodon : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);
    %status_reply = (
        'content' => 'Host not found',
        'reason' => "Internal Exception",
        'status' => 599, # weird way for HTTP::Tiny to report an unknown host
        'success' => "",
        'url' => "https://mastodon.example.org/api/v1/statuses"
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'html');
    my $results = $mastodon->post($comic);

    like($results, qr{\bComic::Social::Mastodon\b}, 'should contain module name');
    like($results, qr{\bHost not found\b}, 'should have error details');
}


sub tells_http_tiny_to_verify_the_server_certificate : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    my $mastodon = Comic::Social::Mastodon->new(%settings, mode => 'html');
    $mastodon->post($comic);

    ok($mastodon->{http}->{verify_SSL}, 'should have passed the verify flag');
}


sub encodes_instance_url : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('post_form', \&mocked_replies);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{'English'} = "https://beercomics.com/comics/latest-comic.html";
    $comic->{pngFile}{'English'} = "latest-comic.png";
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", 'png file contents');

    my $mastodon = Comic::Social::Mastodon->new(%settings, 'mode' => 'png', instance => 'mästödön.de');
    my $results = $mastodon->post($comic);

    my @urls = map { $_->{url} } @posted;
    is_deeply(\@urls, [
        # echo mästödön.de | idn
        'https://xn--mstdn-gra2kb.de/api/v2/media',
        'https://xn--mstdn-gra2kb.de/api/v1/statuses',
    ]);
}
