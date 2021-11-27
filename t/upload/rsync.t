use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use Comic::Upload::Rsync;


__PACKAGE__->runtests() unless caller;


my $fail_on_source;
my @rsync_args;


sub set_up : Test(setup) {
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
