use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use Test::MockModule;

use lib 't';
use MockComic;

use Comic::Upload::Rsync;


__PACKAGE__->runtests() unless caller;


my $fail_on_source;
my @rsync_args;


sub set_up : Test(setup) {
    MockComic::set_up();

    no warnings qw/redefine/;
    *File::Rsync::exec = sub {
        my ($self, @args) = @_;
        push @rsync_args, [@args];
        if ($fail_on_source eq $args[1]) {
            return 0;
        }
        return 1;
    };
    *File::Rsync::realstatus = sub {
        12345;
    };
    *File::Rsync::lastcmd = sub {
        "last rsync command goes here";
    };
    use warnings;

    $fail_on_source = '';
    @rsync_args = ();
}


sub constructor_args : Tests {
    eval {
        Comic::Upload::Rsync->new();
    };
    like($@, qr{Comic::Upload::Rsync}, 'should mention module');
    like($@, qr{\bmissing\b}, 'should say what is wrong');
    like($@, qr{\bsettings\b}, 'should say what argument was expected');

    eval {
        Comic::Upload::Rsync->new('foo');
    };
    like($@, qr{\bhash\b}, 'should say what is wrong');
    like($@, qr{\bsettings\b}, 'should say what argument was expected');

    eval {
        Comic::Upload::Rsync->new('foo' => 'bar');
    };
    like($@, qr{\bmissing\b}, 'should say what is wrong');
    like($@, qr{\bsites\b}, 'should say what argument was expected');

    eval {
        Comic::Upload::Rsync->new('sites' => 1);
    };
    like($@, qr{\bsites\b}, 'should say what argument was wrong');
    like($@, qr{array}, 'should say what is wrong');

    eval {
        Comic::Upload::Rsync->new('sites' => []);
    };
    like($@, qr{\bsites\b}, 'should say what argument was expected');
    like($@, qr{empty}, 'should say what is wrong');

    eval {
        Comic::Upload::Rsync->new(
            'sites' => [
                'english' => {
                    'source' => 'src',
                    'destination' => 'destination',
                },
            ],
            'options' => 1,
        );
    };
    like($@, qr{\boptions\b}, 'should say where it is wrong');
    like($@, qr{\barray\b}, 'should say what is wrong');
}


sub rsyncs_source_target_ok : Tests {
    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
            {
                'source' => 'generated/comics/deutsch',
                'destination' => 'me@example.com/deutsch',
            },
        ],
        'options' => [],
    );

    $rsync->upload();

    is_deeply(\@rsync_args, [
        ['src', 'generated/comics/english', 'dest', 'me@example.com/english'],
        ['src', 'generated/comics/deutsch', 'dest', 'me@example.com/deutsch'],
    ]);
}


sub croaks_if_no_source : Tests {
    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'destination' => 'me@example.com/english',
            },
        ],
    );

    eval {
        $rsync->upload();
    };

    like($@, qr{missing}, 'should say what the problem is');
    like($@, qr{source}, 'should say what is missing');
}


sub croaks_if_no_destination : Tests {
    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => '',
            },
        ],
        'options' => [],
    );

    eval {
        $rsync->upload();
    };

    like($@, qr{missing}, 'should say what the problem is');
    like($@, qr{destination}, 'should say what is missing');
}


sub tries_other_sites_after_error : Tests {
    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
            {
                'source' => 'generated/comics/deutsch',
                'destination' => 'me@example.com/deutsch',
            },
        ],
        'options' => [],
    );
    $fail_on_source = 'generated/comics/english';

    eval {
        $rsync->upload();
    };
    like($@, qr{\bComic::Upload::Rsync\b}m, 'should mention module');
    like($@, qr{\b12345\b}m, 'should have rsync error code');
    like($@, qr{\brsync command goes here\b}m, 'should have rsync command');

    is_deeply(\@rsync_args, [
        ['src', 'generated/comics/english', 'dest', 'me@example.com/english'],
        ['src', 'generated/comics/deutsch', 'dest', 'me@example.com/deutsch'],
    ]);
}


sub passes_ssh_key : Tests {
    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
        'keyfile' => 'my-key.id_rsa',
        'options' => [],
    );

    $rsync->upload();

    is_deeply(\@rsync_args, [
        ['src', 'generated/comics/english', 'dest', 'me@example.com/english', '--rsh', 'ssh -i my-key.id_rsa'],
    ]);
}


sub uses_default_rsync_options_if_none_given : Tests {
    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
    );

    $rsync->upload();

    is_deeply(\@rsync_args, [
        ['src', 'generated/comics/english', 'dest', 'me@example.com/english',
         'checksum', 1, 'compress', 1, 'delete', 1, 'recursive', 1, 'times', 1, 'update', 1],
    ]);
}


sub override_rsync_options : Tests {
    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
        'options' => ['recursive', 'compress'],
    );

    $rsync->upload();

    is_deeply(\@rsync_args, [
        ['src', 'generated/comics/english', 'dest', 'me@example.com/english', 'recursive', 1, 'compress', 1 ],
    ]);
}


sub check_upload_bad_number_of_tries_passed : Tests {
    eval {
        Comic::Upload::Rsync->new(
            'sites' => [
                {
                    'source' => 'generated/comics/english',
                    'destination' => 'me@example.com/english',
                },
            ],
            'check' => 10,
        );
    };
    like($@, qr{\bhash\b}, 'should say what is wrong');
    like($@, qr{\bcheck\b}, 'should mention setting');

    eval {
        Comic::Upload::Rsync->new(
            'sites' => [
                {
                    'source' => 'generated/comics/english',
                    'destination' => 'me@example.com/english',
                },
            ],
            'check' => {
                'delay' => 10,
                'tries' => 'many',
            },
        );
    };
    like($@, qr{check.tries}, 'should mention the setting');
    like($@, qr{number}, 'should state what the problem is');

    eval {
        Comic::Upload::Rsync->new(
            'sites' => [
                {
                    'source' => 'generated/comics/english',
                    'destination' => 'me@example.com/english',
                },
            ],
            'check' => {
                'delay' => 10,
                'tries' => -1,
            },
        );
    };
    like($@, qr{check.tries}, 'should mention the setting');
    like($@, qr{number}, 'should state what the problem is');

    eval {
        Comic::Upload::Rsync->new(
            'sites' => [
                {
                    'source' => 'generated/comics/english',
                    'destination' => 'me@example.com/english',
                },
            ],
            'check' => {
                'delay' => 'a lot',
                'tries' => 10,
            },
        );
    };
    like($@, qr{check.delay}, 'should mention the setting');
    like($@, qr{positive number}, 'should state what the problem is');

    eval {
        Comic::Upload::Rsync->new(
            'sites' => [
                {
                    'source' => 'generated/comics/english',
                    'destination' => 'me@example.com/english',
                },
            ],
            'check' => {
                'delay' => -1,
                'tries' => 10,
            },
        );
    };
    like($@, qr{check\.delay}, 'should mention the setting');
    like($@, qr{positive number}, 'should state what the problem is');
}


sub calls_check_for_all_comics_and_languages : Tests {
    my @urls;
    no warnings qw/redefine/;
    local *Comic::Upload::Rsync::_check_language_url = sub {
        my ($self, $url) = @_;
        push @urls, $url;
    };
    use warnings;

    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
        'check' => {},
    );

    my $comic1 = MockComic::make_comic();
    $comic1->{urlEncoded} = {'Deutsch' => 'comic1/de', 'English' => 'comic1/en'};

    my $comic2 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'zwei' }
    );
    $comic2->{urlEncoded} = {'Deutsch' => 'comic2/de'};

    my $comic3 = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'three' }
    );
    $comic3->{urlEncoded} = {'English' => 'comic3/en'};

    $rsync->upload($comic1, $comic2, $comic3);

    is_deeply(\@urls, ['comic1/de', 'comic1/en', 'comic2/de', 'comic3/en']);
}


sub does_not_call_check_if_none_configured : Tests {
    no warnings qw/redefine/;
    local *Comic::Upload::Rsync::_check_language_url = sub {
        fail('should not have checked');
    };
    use warnings;

    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
    );

    my $comic1 = MockComic::make_comic();

    $rsync->upload($comic1);

    ok(1);  # would have failed in the mocked _check_language_url
}


sub check_upload_hits_url_ok : Tests {
    my @got_urls;

    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('get', sub {
        my ($self, $url) = @_;
        push @got_urls, $url;
        return {success => 1};
    });

    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
        'check' => {
            'delay' => 10,
            'tries' => 10,
        },
    );


    $rsync->_check_urls(MockComic::make_comic());

    is_deeply([
            'https://biercomics.de/comics/bier-trinken.html',
            'https://beercomics.com/comics/drinking-beer.html',
        ],
        \@got_urls,
        'checked wrong URLs');
}


sub check_upload_sleeps_and_retries_eventually_succeds : Tests {
    my $tries = 3;
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('get', sub {
        $tries--;
        return {success => $tries == 0};
    });

    my @slept;
    no warnings qw/redefine/;
    local *Comic::Upload::Rsync::_sleep = sub {
        push @slept, $_[0];
    };
    use warnings;

    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
        'check' => {
            'delay' => 10,
            'tries' => 5,
        },
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Drink beer',
        },
    );
    $rsync->_check_urls($comic);

    is(0, $tries, 'wromg number or retries');
    is_deeply([10, 10], \@slept, 'wrong sleep times');
}


sub check_upload_sleeps_and_retries_till_time_is_out : Tests {
    my $tries;
    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('get', sub {
        $tries++;
        return {success => 0};
    });

    my $slept;
    no warnings qw/redefine/;
    local *Comic::Upload::Rsync::_sleep = sub {
        $slept++;
    };
    use warnings;

    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
        'check' => {
            'delay' => 10,
            'tries' => 30,
        },
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Drink beer',
        },
    );
    eval {
        $rsync->_check_urls($comic);
    };
    like($@, qr{could not get}i, 'should say what is wrong');
    like($@, qr{https://beercomics\.com/comics/drink-beer\.html}, 'should mention URL');

    is($tries, 31, 'wrong number of retries');
    is($slept, 30, 'wrong sleep times');
}


sub check_upload_encodes_url : Tests {
    my @checked;

    my $client = Test::MockModule->new(ref(HTTP::Tiny->new()));
    $client->redefine('get', sub {
        shift @_;
        push @checked, @_;
        return {success => 1};
    });

    my $rsync = Comic::Upload::Rsync->new(
        'sites' => [
            {
                'source' => 'generated/comics/english',
                'destination' => 'me@example.com/english',
            },
        ],
        'Paths' => {
            'siteComics' => 'comics/',
            'published' => 'generated/web/',
            'unpublished' => 'generated/backlog/',
        },
        'check' => {},
    );

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Weißbier',
        },
        $MockComic::SETTINGS => {
            $MockComic::DOMAINS => {
                $MockComic::DEUTSCH => 'cömics.de',
            },
            'Paths' => {
                'siteComics' => 'comics/',
                'published' => 'generated/web/',
                'unpublished' => 'generated/backlog/',
            },
        },
    );

    $rsync->_check_urls($comic);

    is_deeply(\@checked, ['https://xn--cmics-jua.de/comics/wei%C3%9Fbier.html'], 'checked wrong URL');
}
