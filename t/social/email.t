use strict;
use warnings;
use utf8;
use XML::LibXML;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;

use base 'Test::Class';
use Test::More;
use Test::MockModule;

use lib 't';
use MockComic;

use Comic::Social::Email;


__PACKAGE__->runtests() unless caller;


my %default_args;
my $comic;


BEGIN {
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';
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

    my @bodies = $root->getElementsByTagName('body');
    is(@bodies, 1, 'should have exactly 1 body');
    my $body = $bodies[0];

    return $body;
}


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

    $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'blurb goes here' },
    );
    $comic->{url}{English} = "https://beercomics.com/comics/latest-comic.html";

    MockComic::fake_file('recipients.english', 'you@example.org');

    Email::Sender::Simple->default_transport->clear_deliveries();
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

    is_deeply($mailer->{transport}->{_hosts}, [$default_args{server}], 'should use configured server');
    is($mailer->{transport}->{ssl}, 'starttls', 'wrong encryption option');
    is($mailer->{transport}->{sasl_username}, $default_args{sender_address}, 'should use configured user name');
    is($mailer->{transport}->{sasl_password}, $default_args{password}, 'should use configured password');
}


sub sets_email_headers : Tests {
    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    is_deeply(\@warnings, []);

    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    my $email = $deliveries[0]->{email}->cast('Email::MIME');
    my %header = $email->header_str_pairs();
    is($header{'From'}, 'me@example.org', 'wrong sender');
    is($header{'To'}, 'me@example.org', 'wrong recipient');
    is($header{'Subject'}, 'Latest comic', 'wrong subject');
    like($header{'Date'}, qr{^\w{3}, \d{1,2} \w{3} \d{4} \d{2}:\d{2}:\d{2} [+-]\d{4}$}, 'bad date'); # Mon, 13 Nov 2023 11:33:56 -0600
    like($header{'Message-ID'}, qr{^\S+@\S+$}, 'bad message id');
}


sub defaults_to_png_mode : Tests {
    delete $default_args{'mode'};

    my $mailer = Comic::Social::Email->new(%default_args);

    is($mailer->{settings}{'mode'}, 'png');
}


sub builds_link_email : Tests {
    my $mailer = Comic::Social::Email->new(%default_args, mode => 'link');
    $mailer->post($comic);

    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    my $email = $deliveries[0]->{email}->cast('Email::MIME');

    like($email->content_type(), qr{^multipart/mixed}, 'wrong top level content type');
    my @parts = $email->parts();
    is(@parts, 1, 'should have top level MIME part');
    like($parts[0]->content_type(), qr{^multipart/alternative}, 'wrong text part content type');

    @parts = $parts[0]->parts();
    is(@parts, 2, 'should have plain text and html part');

    my $plain = $parts[0];
    like($plain->content_type(), qr{^text/plain}, 'wrong plain text content type');
    like($plain->content_type(), qr{charset=utf-8}, 'wrong plain text charset');
    like($plain->body_str(), qr{blurb goes here}m, 'should have plain text description');
    like($plain->body_str(), qr{https://beercomics.com/comics/latest-comic\.html}m, 'should have plain text link');

    my $html = $parts[1];
    like($html->content_type(), qr{^text/html}, 'wrong html part content type');

    my $body = _html_body($html);
    my @links = $body->getElementsByTagName('a');
    is(@links, 1, 'should have 1 link');
    my $link = $links[0];
    my $attributes = $link->attributes()->{Nodes};
    is_deeply(
        $attributes,
        [XML::LibXML::Attr->new('href', 'https://beercomics.com/comics/latest-comic.html')],
        'Wrong href');
}


sub builds_png_email : Tests {
    $comic->{dirName}{English} = 'generated/web/english/comics/';
    $comic->{pngFile}{English} = 'latest-comic.png';
    @{$comic->{transcript}->{English}} = ('"quoted"');
    MockComic::fake_file("generated/web/english/comics/latest-comic.png", "png goes here");

    my $mailer = Comic::Social::Email->new(%default_args, mode => 'png');
    $mailer->post($comic);

    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    my $email = $deliveries[0]->{email}->cast('Email::MIME');

    like($email->content_type(), qr{^multipart/mixed}, 'wrong top level content type');
    my @top_parts = $email->parts();
    is(@top_parts, 2, 'should have top level MIME part');
    like($top_parts[0]->content_type(), qr{^multipart/alternative}, 'wrong text part content type');

    my @text_parts = $top_parts[0]->parts();
    is(@text_parts, 2, 'should have plain text and html part');

    my $plain = $text_parts[0];
    like($plain->content_type(), qr{^text/plain}, 'wrong plain text content type');
    like($plain->content_type(), qr{charset=utf-8}, 'wrong plain text charset');
    like($plain->body_str(), qr{blurb goes here}m, 'should have plain text description');

    my $html = $text_parts[1];
    like($html->content_type(), qr{^text/html}, 'wrong html part content type');
    my $body = _html_body($html);
    my @paragraphs = $body->getElementsByTagName('p');
    is('blurb goes here',  $paragraphs[0]->textContent(), 'wrong text');
    my @imgs = $body->getElementsByTagName('img');
    is(@imgs, 1, 'should have 1 image');
    my $src = $imgs[0]->getAttribute('src');
    like($src, qr{^cid:\S+@\S+}, 'cid does not look like an email id');
    my $cid = substr $src, 4;   # strip leading cid: to compare against header

    my $image_part = $top_parts[1];
    is($image_part->content_type(), 'image/png', 'wrong png content type');
    my $expected = 'cG5nIGdvZXMgaGVyZQ==';  #  echo -n "png goes here" | base64
    is($image_part->body_raw(), "$expected\r\n", 'should have base64-encoded image data');
    my %header = $image_part->header_str_pairs();
    is($header{'Content-ID'}, "<$cid>", 'Wrong image content id');
    is($header{'Content-Disposition'}, "inline; filename=latest-comic.png", 'Wrong image content disposition');
}


sub encodes_non_ascii_subject : Tests {
    $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Kölsch!' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => '...' },
    );
    $comic->{url}{English} = "https://beercomics.com/comics/latest-comic.html";

    my $mailer = Comic::Social::Email->new(%default_args);
    $mailer->post($comic);

    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    my $email = $deliveries[0]->{email}->cast('Email::MIME');
    my $prefix = '=?UTF-8?B?';      # RFC 2047 MIME encoded word
    my $encoded = 'S8O2bHNjaCE=';   # echo -n "Kölsch!" | base64
    my $suffix = '?=';    # end of encoded word
    # header_str_pairs() decodes, but I want to see the raw header.
    my %headers = $email->header_raw_pairs();
    is($headers{'Subject'}, "$prefix$encoded$suffix", 'wrong subject');
}


sub encodes_non_ascii_in_body : Tests {
    $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Beer?' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Kölsch!' },
    );
    $comic->{url}{English} = "https://beercomics.com/comics/latest-comic.html";

    my $mailer = Comic::Social::Email->new(%default_args, mode => 'link');
    $mailer->post($comic);

    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    my $email = $deliveries[0]->{email}->cast('Email::MIME');
    like($email->as_string(), qr{K=F6lsch!}m, 'wrong body encoding');   # quoted printable
}


sub works_on_all_passed_comics : Tests {
    my @comics;
    foreach my $i ('0', '1', '2') {
        push @comics, MockComic::make_comic(
            $MockComic::TITLE => { $MockComic::ENGLISH => "Comic $i" },
            $MockComic::DESCRIPTION => { $MockComic::ENGLISH => '...' },
        );
    }

    my $mailer = Comic::Social::Email->new(%default_args, mode => 'link');
    $mailer->post(@comics);

    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    is(@deliveries, 3, 'wrong email count');
    foreach my $c (0, 1, 2) {
        my $email = $deliveries[$c]->{email}->cast('Email::MIME');
        my %header = $email->header_str_pairs();
        is($header{'Subject'}, "Comic $c", "wrong subject in comic $c");
    }
}


sub warning_if_sending_fails : Tests {
    my $smtp = Test::MockModule->new('Email::Sender::Transport::Test');
    $smtp->redefine('recipient_failure', sub {
        return Email::Sender::Failure->new({
            'code' => 535,
            'message' => "failed AUTH: 5.7.8 Username and Password not accepted. Learn more at\n" .
                "5.7.8  https://support.google.com/...",
            'recipients' => ['you@example.org'],
        });
    });

    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    is(@warnings, 1, 'should have one message');
    like($warnings[0], qr{^Comic::Social::Email}, 'should have module name');
    like($warnings[0], qr{\bEnglish\b}, 'should mention language');
    like($warnings[0], qr{\byou\@example.org\b}, 'should mention recipient');
    like($warnings[0], qr{\bUsername and Password not accepted\b}, 'should have exception message');
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
    no warnings qw/redefine/;
    local *File::Slurper::read_lines = sub {
        die "cannot read!";
    };
    use warnings;

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

    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    is(@deliveries, 0, 'should not have sent anything');
}


sub skips_empty_lines_in_recipient_list : Tests {
    MockComic::fake_file('recipients.english',  "\n\n\r\nme\@example.org\r\n\r\nyou\@example.org\n  \n");

    my $mailer = Comic::Social::Email->new(%default_args);
    my @warnings = $mailer->post($comic);

    is_deeply(\@warnings, []);
    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    is(@deliveries, 1, 'should have sent one email');
    is_deeply($deliveries[0]->{successes}, ['me@example.org', 'you@example.org']);
}
