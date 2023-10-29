use strict;
use warnings;
use utf8;
use XML::LibXML;

use base 'Test::Class';
use Test::More;
use Test::MockModule;
use Test::MockFile qw(nostrict);    # not strict so that require and use statememts still work

use lib 't';
use MockComic;

use Comic::Social::Email;
use Email::Stuffer;


__PACKAGE__->runtests() unless caller;


my %default_args;
my $smtp;
my $stuffer;
my $comic;


sub set_up : Test(setup) {
    MockComic::set_up();

    %default_args = (
        'server' => 'smtp.example.org',
        'sender_address' => 'me@example.org',
        'password' => 'secret',
        'recipient_list' => {
            'English' => 'recipients.english',
        },
        'mode' => 'link',
    );

    $smtp = Test::MockModule->new('Email::Stuffer');
    $smtp->redefine('send_or_die', sub {
        $stuffer = shift;
        return 1;
    });

    $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'blurb goes here' },
    );
    $comic->{url}{English} = "https://beercomics.com/comics/latest-comic.html";

    MockComic::fake_file('recipients.english', 'you@example.org');
}


sub complains_about_missing_args : Tests {
    eval {
        Comic::Social::Email->new();
    };
    like($@, qr{Comic::Social::Email}, 'should mention module');
    like($@, qr{\bmissing\b}, 'should say what is wrong');
    like($@, qr{\bsettings\b}, 'should say what argument was expected');

    eval {
        Comic::Social::Email->new('foo');
    };
    like($@, qr{\bhash\b}, 'should say what is wrong');
    like($@, qr{\bsettings\b}, 'should say what argument was expected');
}


sub complains_about_bad_server : Tests {
    eval {
        Comic::Social::Email->new(
            'sender_address' => 'me@example.org',
            'password' => 'secret',
            'recipient_list' => {},
        );
    };
    like($@, qr{\bserver\b}, 'should say what argument was missing');
    like($@, qr{missing}, 'should say what is wrong');
    like($@, qr{empty}, 'should say what is wrong');

    eval {
        Comic::Social::Email->new(
            'server' => 'http://example.org',
            'sender_address' => 'me@example.org',
            'password' => 'secret',
            'recipient_list' => {},
        );
    };
    like($@, qr{\bserver\b}, 'should say what argument had a problem');
    like($@, qr{invalid characters}, 'should say what is wrong');
}


sub complains_about_bad_sender_address_email : Tests {
    eval {
        Comic::Social::Email->new(
            'server' => 'smtp.example.org',
            'password' => 'secret',
            'recipient_list' => {},
        );
    };
    like($@, qr{\bsender_address\b}, 'should say what argument was missing');
    like($@, qr{missing}, 'should say what is wrong');

    eval {
        Comic::Social::Email->new(
            'server' => 'smtp.example.org',
            'sender_address' => 'me here',
            'password' => 'secret',
            'recipient_list' => {},
        );
    };
    like($@, qr{\bsender_address\b}, 'should say what argument had a problem');
    like($@, qr{email address}, 'should say what is wrong');
}


sub complains_about_bad_password : Tests {
    eval {
        Comic::Social::Email->new(
            'server' => 'smtp.example.org',
            'sender_address' => 'me@example.org',
            'recipient_list' => {},
        );
    };
    like($@, qr{\bpassword\b}, 'should say what argument was missing');
    like($@, qr{missing}, 'should say what is wrong');

    eval {
        Comic::Social::Email->new(
            'server' => 'smtp.example.org',
            'sender_address' => 'me@example.org',
            'password' => '',
            'recipient_list' => {},
        );
    };
    like($@, qr{\bpassword\b}, 'should say what argument had a problem');
    like($@, qr{missing}, 'should say what is wrong');
}


sub complains_about_bad_recipient_list : Tests {
    eval {
        Comic::Social::Email->new(
            'server' => 'smtp.example.org',
            'sender_address' => 'me@example.org',
            'password' => 'secret',
        );
    };
    like($@, qr{\brecipient_list\b}, 'should say what argument was missing');
    like($@, qr{missing}, 'should say what is wrong');

    eval {
        Comic::Social::Email->new(
            'server' => 'smtp.example.org',
            'sender_address' => 'me@example.org',
            'password' => 'secret',
            'recipient_list' => 'some file',
        );
    };
    like($@, qr{\brecipient_list\b}, 'should say what argument had a problem');
    like($@, qr{hash}, 'should say what is wrong');
}


sub complains_about_bad_mode : Tests {
    eval {
        Comic::Social::Email->new(
            %default_args,
            'mode' => {},
        );
    };
    like($@, qr{\bmode\b}, 'should say what argument had a problem');
    like($@, qr{\bpng or link\b}, 'should say what is wrong');

    eval {
        Comic::Social::Email->new(
            %default_args,
            'mode' => 'whatever',
        );
    };
    like($@, qr{\bmode\b}, 'should say what argument had a problem');
    like($@, qr{\bpng or link\b}, 'should say what is wrong');
}


sub uses_passed_server_and_credentials : Tests {
    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    my $transport = $stuffer->{transport};
    is_deeply($transport->{_hosts}, [$default_args{server}], 'should use configured server');
    is($transport->{ssl}, 'starttls', 'wrong encryption option');
    is($transport->{sasl_username}, $default_args{sender_address}, 'should use configured user name');
    is($transport->{sasl_password}, $default_args{password}, 'should use configured password');
}


sub sets_email_headers : Tests {
    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    is_deeply(\@warnings, []);
    my %header = $stuffer->email()->header_str_pairs();
    is($header{'From'}, 'me@example.org', 'wrong sender');
    is($header{'To'}, 'you@example.org', 'wrong recipient');
    is($header{'Subject'}, 'Latest comic', 'wrong subject');
}


sub defaults_to_png_mode : Tests {
    delete $default_args{'mode'};

    my $mailer = Comic::Social::Email->new(%default_args);

    is($mailer->{settings}{'mode'}, 'png');
}


sub builds_link_email : Tests {
    my $mailer = Comic::Social::Email->new(%default_args, mode => 'link');
    $mailer->post($comic);

    my @parts = $stuffer->email->subparts;
    is(@parts, 2, 'should have plain text and html part');

    is($parts[0]->content_type(), 'text/plain; charset=utf-8', 'wrong plain text content type');
    like($parts[0]->body_str(), qr{blurb goes here}m, 'should have plain text description');
    like($parts[0]->body_str(), qr{https://beercomics.com/comics/latest-comic\.html}m, 'should have plain text link');

    my $body = _html_body($parts[1]);
    my @links = $body->getElementsByTagName('a');
    is(@links, 1, 'should have 1 link');
    my $link = $links[0];
    my $attributes = $link->attributes()->{Nodes};
    is_deeply(
        $attributes,
        [XML::LibXML::Attr->new('href', 'https://beercomics.com/comics/latest-comic.html')],
        'Wrong href');
}


sub _html_body {
    my $part = shift;

    is($part->content_type(), 'text/html; charset=utf-8', 'wrong html content type');

    my $parser = XML::LibXML->new();
    my $dom = $parser->load_html(string => $part->body_str(), recover => 0);   # don't recover, fail nosily

    my $root = $dom->documentElement();
    is($root->nodeName(), 'html', 'root element should be <html>');
    is_deeply($root->attributes()->{Nodes}, [XML::LibXML::Attr->new('lang', 'en')], '<html> should have lang attribute');

    my @heads = $root->getElementsByTagName('head');
    is(@heads, 1, 'should have exactly 1 head');
    my $head = $heads[0];

    my @bodies = $root->getElementsByTagName('body');
    is(@bodies, 1, 'should have exactly 1 body');
    my $body = $bodies[0];

    return $body;
}


sub builds_png_email : Tests {
    $comic->{dirName}{English} = 'generated/web/english/comics/';
    $comic->{pngFile}{English} = 'latest-comic.png';
    @{$comic->{transcript}->{English}} = ('"quoted"');
    my $png = Test::MockFile->file("generated/web/english/comics/latest-comic.png", "png goes here");

    my $mailer = Comic::Social::Email->new(%default_args, mode => 'png');
    $mailer->post($comic);

    my @parts = $stuffer->email->subparts;
    is(@parts, 3, 'should have plain text, html part, and image attachment');

    is($parts[0]->content_type(), 'text/plain; charset=utf-8', 'wrong plain text content type');
    like($parts[0]->body_str(), qr{blurb goes here}m, 'should have plain text description');

    my $body = _html_body($parts[1]);
    my @paragraphs = $body->getElementsByTagName('p');
    is('blurb goes here',  $paragraphs[0]->textContent(), 'wrong text');

    is($parts[2]->content_type(), 'image/png; name=latest-comic.png', 'wrong png content type');
    my $expected = 'cG5nIGdvZXMgaGVyZQ==';  #  echo -n "png goes here" | base64
    is($parts[2]->body_raw(), "$expected\r\n", 'should have base64-encoded image data');
    my %header = $parts[2]->header_str_pairs();
    my $cid = $header{'Content-ID'};
    like($cid, qr{<[\w.-]+@[\w.-]+>}, 'CID should have local part and domain');
    $cid =~ s{^<}{};
    $cid =~ s{>$}{};

    my @imgs = $body->getElementsByTagName('img');
    is(@imgs, 1, 'should have 1 image link');
    my @attributes = $imgs[0]->attributes()->{Nodes};
    is_deeply(@attributes, [
        XML::LibXML::Attr->new('src', "cid:$cid"),
        XML::LibXML::Attr->new('alt', '"quoted"'),   # XML::LibXML::Attr->new encodes
    ]);
}


sub encodes_non_ascii_subject : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Kölsch!' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => '...' },
    );
    $comic->{url}{English} = "https://beercomics.com/comics/latest-comic.html";

    my $mailer = Comic::Social::Email->new(%default_args);
    $mailer->post($comic);

    # $stuffer->email()->header_str_pairs() decodes, but I want to see the raw header.
    my $prefix = 'Subject: =\\?UTF-8\\?B\\?';      # RFC 2047 MIME encoded word
    my $encoded = 'S8O2bHNjaCE=';   # echo -n "Kölsch!" | base64
    my $suffix = '\\?=';
    like($stuffer->as_string(), qr{$prefix$encoded$suffix}m, 'wrong subject');
}


sub encodes_non_ascii_in_body : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Beer?' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Kölsch!' },
    );
    $comic->{url}{English} = "https://beercomics.com/comics/latest-comic.html";

    my $mailer = Comic::Social::Email->new(%default_args, mode => 'link');
    $mailer->post($comic);

    like($stuffer->as_string(), qr{K=C3=B6lsch!}m, 'wrong subject');
}


sub works_on_all_passed_comics : Tests {
    my @mailed;

    $smtp->redefine('send_or_die', sub {
        my $stuffer = shift;
        my %header = $stuffer->email()->header_str_pairs();
        push @mailed, $header{'Subject'};
        return;
    });
    my @comics;
    foreach my $i ('1', '2', '3') {
        push @comics, MockComic::make_comic(
            $MockComic::TITLE => { $MockComic::ENGLISH => "Comic $i" },
            $MockComic::DESCRIPTION => { $MockComic::ENGLISH => '...' },
        );
    }

    my $mailer = Comic::Social::Email->new(%default_args, mode => 'link');
    $mailer->post(@comics);

    is_deeply(\@mailed, ['Comic 1', 'Comic 2', 'Comic 3']);
}


sub warning_if_sending_fails : Tests {
    $smtp->redefine('send_or_die', sub {
        die 'go away';
    });

    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    is(@warnings, 1, 'should have one message');
    like($warnings[0], qr{^Comic::Social::Email}, 'should have module name');
    like($warnings[0], qr{\bEnglish\b}, 'should mention language');
    like($warnings[0], qr{\byou\@example.org\b}, 'should mention recipient');
    like($warnings[0], qr{\bgo away\b}, 'should have exception message');
}


sub warns_if_no_recipient_list_for_language : Tests {
    my $mailer = Comic::Social::Email->new(%default_args, 'recipient_list' => {});
    my @warnings = $mailer->post($comic);

    is(@warnings, 1, 'should have one message');
    like($warnings[0], qr{^Comic::Social::Email}, 'should have module name');
    like($warnings[0], qr{\bEnglish\b}, 'should mention language');
    like($warnings[0], qr{\brecipient list\b}, 'should say what was wrong');
}


sub warns_on_problems_reading_recipient_list : Tests {
    local *File::Slurper::read_lines = sub {
        die "cannot read!";
    };

    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    is(@warnings, 1, 'should have one message');
    like($warnings[0], qr{^Comic::Social::Email}, 'should have module name');
    like($warnings[0], qr{\bEnglish\b}, 'should mention language');
    like($warnings[0], qr{\brecipient list\b}, 'should say where the problem was');
    like($warnings[0], qr{\brecipients\.english\b}, 'should include the file name');
    like($warnings[0], qr{\bcannot read!}, 'should have the exception message');
}


sub warns_if_recipient_list_is_empty : Tests {
    MockComic::fake_file('has-nothing', '');

    my $mailer = Comic::Social::Email->new(%default_args, 'recipient_list' => { 'English' => 'has-nothing'});
    my @warnings = $mailer->post($comic);

    is(@warnings, 1, 'should have one message');
    like($warnings[0], qr{^Comic::Social::Email}, 'should have module name');
    like($warnings[0], qr{\bEnglish\b}, 'should mention language');
    like($warnings[0], qr{\brecipient list\b}, 'should say where the problem was');
    like($warnings[0], qr{\bempty\b}, 'should say what was wrong');
}


sub skips_empty_lines_in_recipient_list : Tests {
    my @mailed;

    $smtp->redefine('send_or_die', sub {
        my $stuffer = shift;
        my %header = $stuffer->email()->header_str_pairs();
        push @mailed, $header{'To'};
        return 1;
    });

    MockComic::fake_file('recipients.english',  "\n\n\r\nme\@example.org\r\n\r\nyou\@example.org\n  \n");

    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    is_deeply(\@mailed, ['me@example.org', 'you@example.org']);
    is_deeply(\@warnings, []);
}
