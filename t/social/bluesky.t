use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;

use Comic::Social::Bluesky;
use JSON;


__PACKAGE__->runtests() unless caller;


my %settings;
my %assertions;
my %replies;
my @posted;


sub set_up : Test(setup) {
    MockComic::set_up();

    %settings = (
        'username' => 'the-bluesky-user',
        'password' => 'secret',
        'mode' => 'link',
    );
    %assertions = (
        'createSession' => sub {
            my ($url, $options) = @_;
            ok($url =~ m{https://.+/xrpc/com.atproto.server.createSession$}x);
            is($options->{headers}->{'Content-Type'}, 'application/json', "Wrong content type on $url");
            my $content = decode_json($options->{content});
            is($content->{identifier}, $settings{'username'}, 'wrong username on login');
            is($content->{password}, $settings{'password'}, 'wrong password on login');
        },
        'createRecord' => sub {
            my ($url, $options) = @_;
            ok($url =~ m{https://.+/xrpc/com.atproto.repo.createRecord$}x);
            is($options->{headers}->{'Content-Type'}, 'application/json', "Wrong content type on $url");
            is($options->{headers}->{Authorization}, 'Bearer atoken', "Wrong auth header");
        },
        'uploadBlob' => sub {
            my ($url, $options) = @_;
            ok($url =~ m{https://.+/xrpc/com.atproto.repo.uploadBlob$});
            is($options->{headers}->{'Content-Type'}, undef, "Wrong content type on $url");
            is($options->{headers}->{Authorization}, 'Bearer atoken', "Wrong auth header");
        },
    );
    %replies = (
        'createSession' => {
            'success' => 1,
            'status' => 200,
            'content' => '{"accessJwt":"atoken", "did": "the-did"}',
        },
        'createRecord' => {
            'success' => 1,
            'content' => '{"uri": "at://posted", "cid": "abc"}',
            'status' => 200,
        },
        'uploadBlob' => {
            'success' => 1,
            'content' => '{"blob": "blob-id"}',
            'status' => 200,
        },
    );
    @posted = ();
}


sub mock_request {
    my ($self, $method, $url, $options) = @_;

    is($method, 'POST', "bad HTTP method on $url");

    push @posted, $options;

    foreach my $url_fragment (keys %assertions) {
        if ($url =~ m{$url_fragment}) {
            $assertions{$url_fragment}($url, $options);
        }
    }
    foreach my $url_fragment (keys %replies) {
        if ($url =~ m{$url_fragment}) {
            return $replies{$url_fragment};
        }
    }
    ok(0, "Unknown URL $url");
}


sub complains_about_missing_configuration : Tests {
    eval {
        Comic::Social::Bluesky->new();
    };
    like($@, qr(Comic::Social::Bluesky), 'should say the module name');
    like($@, qr(configuration missing)i, 'should say what is wrong');

    eval {
        Comic::Social::Bluesky->new(
            'password' => 'secret',
            'mode' => 'png',
        );
    };
    like($@, qr(Comic::Social::Bluesky), 'should say the module name');
    like($@, qr(\busername\b), 'should say what is missing');

    eval {
        Comic::Social::Bluesky->new(
            'username' => 'me',
            'password' =>  'secret',
        );
    };
    like($@, qr(Comic::Social::Bluesky), 'should say the module name');
    like($@, qr(\bmode\b), 'should say what is missing');

    eval {
        Comic::Social::Bluesky->new(
            'username' => 'me',
            'mode' => 'png',
       );
    };
    like($@, qr(Comic::Social::Bluesky), 'should say the module name');
    like($@, qr(\bpassword\b), 'should say what is missing');
}


sub complains_about_bad_mode : Tests {
    eval {
        Comic::Social::Bluesky->new(
            'username' => 'me',
            'password' => 'secret',
            'mode' => 'whatever',
       );
    };
    like($@, qr(Comic::Social::Bluesky), 'should say the module name');
    like($@, qr(\bmode\b), 'should say what is wrong');
    like($@, qr(\blink\b), 'should mention link option');
    like($@, qr(\bpng\b), 'should png option');
}


sub service_defaults_to_bsky_social : Tests {
    my $bs = Comic::Social::Bluesky->new(%settings);
    is($bs->{settings}->{service}, 'https://bsky.social');
}


sub adds_protocol_to_service_if_not_given_and_forces_https : Tests {
    my $bs = Comic::Social::Bluesky->new(%settings, 'service' => 'http://blue.sky');
    is($bs->{settings}->{service}, 'https://blue.sky');

    $bs = Comic::Social::Bluesky->new(%settings, 'service' => 'blue.sky');
    is($bs->{settings}->{service}, 'https://blue.sky');
}


sub removes_trailing_slash_from_service : Tests {
    my $bs = Comic::Social::Bluesky->new(%settings, 'service' => 'https://blue.sky');
    is($bs->{settings}->{service}, 'https://blue.sky');

    $bs = Comic::Social::Bluesky->new(%settings, 'service' => 'https://blue.sky/');
    is($bs->{settings}->{service}, 'https://blue.sky');
}


sub encodes_domain : Tests {
    my $bs = Comic::Social::Bluesky->new(%settings, 'service' => 'blüsky.de');
    is($bs->{settings}->{service}, 'https://xn--blsky-lva.de');  # echo blüsky.de | idn
}


sub fails_if_log_in_fails : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    $replies{createSession} = {
        'success' => 0,
        'status' => 401,
        'reason' => 'unauthorized',
        'content' => '{"error": "go away", "message":"bad password"}',
    };
    my $comic = MockComic::make_comic();

    my $bs = Comic::Social::Bluesky->new(%settings);
    my @results = $bs->post($comic);

    is_deeply(\@results, ['Comic::Social::Bluesky: Error logging in to https://bsky.social: HTTP error 401 on login: unauthorized']);
}


sub handles_bad_json_on_login_gracefully : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    $replies{createSession} = {
        'success' => 1,
        'status' => 200,
        'content' => 'not json',
    };
    my $comic = MockComic::make_comic();

    my $bs = Comic::Social::Bluesky->new(%settings);
    my @results = $bs->post($comic);

    is(@results, 1, 'should habe 1 error');
    like($results[0], qr{Comic::Social::Bluesky}, 'should have the module name');
    like($results[0], qr{\bbad JSON\b}i, 'should say what is wrong');
}


sub handles_dns_error_gracefully : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    $replies{createSession} = {
        'success' => 0,
        'status' => 599,
        'content' => 'DNS error',
    };
    my $comic = MockComic::make_comic();

    my $bs = Comic::Social::Bluesky->new(%settings);
    my @results = $bs->post($comic);

    is_deeply(\@results, ['Comic::Social::Bluesky: Error logging in to https://bsky.social: DNS error']);
}


sub posts_link : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
        },
    );
    $comic->{rfc3339pubDate} = 'Sat, 30 Mar 2024 00:00::00';

    my $bs = Comic::Social::Bluesky->new(%settings);
    my @results = $bs->post($comic);

    is(@posted, 2, 'wrong number of posts');
    my $options = $posted[1];
    my $content = decode_json($options->{content});
    is($content->{repo}, 'the-did', "Wrong repo / didurl");
    is($content->{collection}, 'app.bsky.feed.post', "Wrong collection");
    is($content->{record}->{text}, "Blue sky beer\nhttps://beercomics.com/comics/blue-sky-beer.html", "Wrong text");
    is($content->{record}->{createdAt}, 'Sat, 30 Mar 2024 00:00::00', "Wrong timestamp");
    is_deeply($content->{record}->{langs}, [ 'en' ]);

    is_deeply(\@results, ['Comic::Social::Bluesky: posted Blue sky beer link']);
}


sub posts_in_all_languages : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
            $MockComic::DEUTSCH => 'Blauhimmelbier',
        },
    );
    $comic->{rfc3339pubDate} = 'Sat, 30 Mar 2024 00:00::00';

    my $bs = Comic::Social::Bluesky->new(%settings);
    my @results = $bs->post($comic);

    is(@posted, 3, 'wrong number of posts');

    my $options = $posted[1];
    my $content = decode_json($options->{content});
    is($content->{repo}, 'the-did', "Wrong repo / didurl");
    is($content->{collection}, 'app.bsky.feed.post', "Wrong collection");
    is($content->{record}->{text}, "Blauhimmelbier\nhttps://biercomics.de/comics/blauhimmelbier.html", "Wrong text");
    is($content->{record}->{createdAt}, 'Sat, 30 Mar 2024 00:00::00', "Wrong timestamp");
    is_deeply($content->{record}->{langs}, [ 'de' ]);

    $options = $posted[2];
    $content = decode_json($options->{content});
    is($content->{repo}, 'the-did', "Wrong repo / didurl");
    is($content->{collection}, 'app.bsky.feed.post', "Wrong collection");
    is($content->{record}->{text}, "Blue sky beer\nhttps://beercomics.com/comics/blue-sky-beer.html", "Wrong text");
    is($content->{record}->{createdAt}, 'Sat, 30 Mar 2024 00:00::00', "Wrong timestamp");
    is_deeply($content->{record}->{langs}, [ 'en' ]);

    is_deeply(\@results, [
        "Comic::Social::Bluesky: posted Blauhimmelbier link\n" .
        "Comic::Social::Bluesky: posted Blue sky beer link"
    ]);
}


sub handles_bad_json_on_posting_gracefully : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    $replies{createRecord} = {
        'success' => 1,
        'status' => 200,
        'content' => 'not json',
    };
    my $comic = MockComic::make_comic();

    my $bs = Comic::Social::Bluesky->new(%settings);
    my @results = $bs->post($comic);

    is(@results, 1, 'should habe 1 error');
    like($results[0], qr{Comic::Social::Bluesky}, 'should have the module name');
    like($results[0], qr{\bbad JSON\b}i, 'should say what is wrong');
}


sub posts_image : Tests {
    MockComic::fake_file('generated/web/English/comics/blue_sky_beer.png', 'comic goes here');
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => 'Described as blue',
        }
    );
    $comic->{rfc3339pubDate} = 'Sat, 30 Mar 2024 00:00::00';
    $comic->{dirName}->{'English'} = 'generated/web/English/comics/';
    $comic->{pngFile}->{'English'} = 'blue_sky_beer.png';
    $comic->{width}->{'English'} = 123;
    $comic->{height}->{'English'} = 456;

    my $bs = Comic::Social::Bluesky->new(%settings, 'mode' => 'png');
    my @results = $bs->post($comic);

    is(@posted, 3, 'wrong number of posts');

    my $blob = $posted[1]->{content};
    is('comic goes here', $blob);

    my $options = $posted[2];
    my $content = decode_json($options->{content});
    is($content->{repo}, 'the-did', "Wrong repo / didurl");
    is($content->{collection}, 'app.bsky.feed.post', "Wrong collection");
    is($content->{record}->{text}, "Blue sky beer\nDescribed as blue", "Wrong text");
    is($content->{record}->{createdAt}, 'Sat, 30 Mar 2024 00:00::00', "Wrong timestamp");
    is_deeply($content->{record}->{langs}, [ 'en' ]);
    is_deeply($content->{record}->{embed}, {
        '$type' => 'app.bsky.embed.images',
        images => [
            {
                alt => "Described as blue",
                image => 'blob-id',
                aspectRatio => {
                    width => 123,
                    height => 456,
                }
            }
        ],
    });

    is_deeply(\@results, [
        'Comic::Social::Bluesky: posted Blue sky beer png'
    ]);
}


sub clears_out_image_blob : Tests {
    MockComic::fake_file('generated/web/English/comics/blue_sky_beer.png', 'comic goes here');
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => 'Described as blue',
        }
    );
    $comic->{rfc3339pubDate} = 'Sat, 30 Mar 2024 00:00::00';
    $comic->{dirName}->{'English'} = 'generated/web/English/comics/';
    $comic->{pngFile}->{'English'} = 'blue_sky_beer.png';
    $comic->{width}->{'English'} = 123;
    $comic->{height}->{'English'} = 456;

    my $bs = Comic::Social::Bluesky->new(%settings, 'mode' => 'png');
    $bs->post($comic);

    is($bs->{blob_id}, undef);
}


sub handles_bad_json_on_image_upload_gracefully : Tests {
    MockComic::fake_file('generated/web/English/comics/blue_sky_beer.png', 'comic goes here');
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    $replies{uploadBlob} = {
        'success' => 1,
        'status' => 200,
        'content' => 'not json',
    };
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Drinking beer',
        },
    );
    $comic->{dirName}->{'English'} = 'generated/web/English/comics/';
    $comic->{pngFile}->{'English'} = 'blue_sky_beer.png';

    my $bs = Comic::Social::Bluesky->new(%settings, mode => 'png');
    my @results = $bs->post($comic);

    is(@results, 1, 'should habe 1 error');
    like($results[0], qr{Comic::Social::Bluesky}, 'should have the module name');
    like($results[0], qr{\bbad JSON\b}i, 'should say what is wrong');
}


sub text_length : Tests {
    is(Comic::Social::Bluesky::_textlen(), 0, 'no text passed');
    is(Comic::Social::Bluesky::_textlen('a'), 1, 'single ascii character');
    is(Comic::Social::Bluesky::_textlen('test'), 4, 'ascii text');
    is(Comic::Social::Bluesky::_textlen('Bär'), 1 + 2 + 1, 'utf8 with umlaut');
    is(Comic::Social::Bluesky::_textlen('👨‍👩‍👧‍👧'), 25, 'emojis');
    is(Comic::Social::Bluesky::_textlen('🍺'), 4, 'beer emoji'); # U+1F37A
}


sub hyperlink_facet : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blü sky beer',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => '🍺',
        },
    );
    $comic->{url}->{English} = 'https://example.org/blüsky.html';

    my $got = Comic::Social::Bluesky::_build_message($comic, 'English', 'link');

    is_deeply($got, {
        text => "Blü sky beer\n🍺\nhttps://example.org/blüsky.html",
        #        0   5    10   14   20   25   30   35   40  45   50
        facets => [
            {
                index => {
                    byteStart => 19,
                    byteEnd => 51,
                },
                features => [{
                    '$type' => 'app.bsky.richtext.facet#link',
                    uri => 'https://example.org/blüsky.html',
                }],
            },
        ],
    });
}


sub tags_facet : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => 'Beer as blue as the sky',
        },
        $MockComic::HASH_TAGS => {
            $MockComic::ENGLISH => [ '#general' ],
        },
        $MockComic::BLUESKY => {
            $MockComic::ENGLISH => [ '#bläu', '🍺'],
        },
    );
    $comic->{url}->{English} = 'https://example.org/bluesky.html';

    # Blue sky beer\nBeer as blue as the sky\n#general #bläu 🍺
    # 0    5    10    15   20   25   30   35    40   45   50

    my $got = Comic::Social::Bluesky::_build_message($comic, 'English', 'png');

    is_deeply($got->{facets}, [
        {
            index => {
                byteStart => 38,
                byteEnd => 46,
            },
            features => [{
                '$type' => 'app.bsky.richtext.facet#tag',
                tag => 'general',
            }],
        },
        {
            index => {
                byteStart => 47,
                byteEnd => 53,
            },
            features => [{
                '$type' => 'app.bsky.richtext.facet#tag',
                tag => 'bläu',
            }],
        },
        {
            index => {
                byteStart => 54,
                byteEnd => 58,
            },
            features => [{
                '$type' => 'app.bsky.richtext.facet#tag',
                tag => '🍺',
            }],
        },
    ]);
}


sub mention_facet : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => 'Beer as blue as the sky',
        },
        $MockComic::HASH_TAGS => {
            $MockComic::ENGLISH => [ '@me' ],
        },
    );
    $comic->{url}->{English} = 'https://example.org/bluesky.html';

    # Blue sky beer\nBeer as blue as the sky\n@me
    # 0    5    10    15   20   25   30   35    40   46   50

    my $got = Comic::Social::Bluesky::_build_message($comic, 'English', 'png');

    is_deeply($got->{facets}, [
        {
            index => {
                byteStart => 38,
                byteEnd => 41,
            },
            features => [{
                '$type' => 'app.bsky.richtext.facet#mention',
                tag => 'me',
            }],
        },
   ]);
}


sub no_facets : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::ENGLISH => '...',
        },
    );

    my $got = Comic::Social::Bluesky::_build_message($comic, 'English', 'png');

    is_deeply($got, {
        text => "Blue sky beer\n..."
    });
}


sub caches_auth : Tests {
    my $logins = 0;
    $assertions{createSession} = sub {
        $logins++;
    };
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Test',
        },
    );
    my $bs = Comic::Social::Bluesky->new(%settings);

    $bs->post($comic);
    $bs->post($comic);

    is($logins, 1, 'wrong login count');
}


sub does_not_cache_auth_if_login_failed : Tests {
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    $replies{'createSession'} = {
        'success' => 0,
        'status' => 500,
        'reason' => 'internal server error',
    },
    my $comic = MockComic::make_comic();
    my $bs = Comic::Social::Bluesky->new(%settings);

    $bs->post($comic);

    is($bs->{http}, undef, 'should not hold on to HTTP cliemt');
}


sub posts_link_if_image_upload_fails : Tests {
    MockComic::fake_file('generated/web/English/comics/blue_sky_beer.png', 'comic goes here');
    $replies{uploadBlob} = {
        success => 0,
        status => 400,
        reason => 'bad request',
    };
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('request', \&mock_request);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Blue sky beer',
        },
    );
    $comic->{dirName}->{'English'} = 'generated/web/English/comics/';
    $comic->{pngFile}->{'English'} = 'blue_sky_beer.png';
    my $bs = Comic::Social::Bluesky->new(%settings, mode => 'png');

    my @results = $bs->post($comic);

    is(@posted, 3, 'wrong number of posts');
    my $options = $posted[2];
    my $content = decode_json($options->{content});
    is($content->{record}->{text}, "Blue sky beer\nhttps://beercomics.com/comics/blue-sky-beer.html", "Wrong text");
    is($content->{record}->{embed}, undef, 'Should not have an embed block');

    is_deeply(\@results, [
        "Comic::Social::Bluesky: error uploading png for Blue sky beer: HTTP error 400 on login: bad request\n" .
        "Comic::Social::Bluesky: posted Blue sky beer link"
    ]);
    is($bs->{blob_id}, undef, 'should have cleared out the blob id');
}
