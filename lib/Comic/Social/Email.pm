package Comic::Social::Email;

use strict;
use warnings;
use utf8;
use Carp;
use English '-no_match_vars';
use HTML::Entities;

use version; our $VERSION = qv('0.0.3');

use Comic::Social::Social;
use base('Comic::Social::Social');

use File::Slurper;
use Email::MIME;
use Email::MessageID;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;


=encoding utf8

=for stopwords Wenner merchantability perlartistic Uploader Uploaders SMTP png


=head1 NAME

Comic::Social::Email - email (a link to) the latest comic.

=head1 SYNOPSIS

    my $index_now = Comic::Social::Email->new({
        'sender_address' => 'me@example.org',
        'password' => 'super secret',
        'server' => 'smtp.example.com',
        'recipient_list' => '/path/to/recipients.txt',
    });

=head1 DESCRIPTION

Sends the latest comic (or a link to it) to the recipients from a given text
file.

This may or may not work for lots (over a few hundred) of recipients, or you
may need to run your own SMTP server, which may or may not have its own
problems in regards to reputation management. Email list management (e.g.,
subscribing and unsubscribing) is not part of this module.

=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::Email.

Parameters:

=over 4

=item * B<%settings> Hash reference with settings, as below.

=back

The passed settings must be a hash reference like this:

    {
        "sender_address" => "your email address",
        "password" => "to send on your behalf",
        "server" => "smtp.example.org",
        "recipient_list" => "/path/to/recipients.txt",
        "mode" => "png",
    }

The C<sender_address> is your email address, e.g., C<me@example.org>.

The C<password> is used to log in to the given C<server>.

The C<recipient_list> is the path to a text file with an email address on
each line.

The C<mode> specifies whether to send the comic's png image ("png") as an
attachment or just a link to the comic ("link"). Defaults to "png".

=cut

sub new {
    my $class = shift @ARG;
    my $self = bless{}, $class;

    $self->_croak('settings hash is missing') unless(@ARG);
    $self->_croak('settings must be a hash') unless (@ARG % 2 == 0);
    $self->{settings} = {@ARG};

    $self->_croak('server is missing or empty') unless ($self->{settings}{'server'});
    $self->_croak('server contains invalid characters') if ($self->{settings}{'server'} !~ m{^[\w.]+$});

    $self->_croak('sender_address is missing or empty') unless ($self->{settings}{'sender_address'});
    $self->_croak('sender_address must be an email address') if ($self->{settings}{'sender_address'} !~ m{^.+@.+$});

    $self->_croak('password is missing or empty') unless ($self->{settings}{'password'});

    $self->_croak('recipient_list is missing or empty') unless ($self->{settings}{'recipient_list'});
    $self->_croak('recipient_list must be a hash (object) of languages to files/paths')
        unless (ref $self->{settings}{'recipient_list'} eq ref {});

    $self->{settings}{mode} ||= 'png';
    $self->_croak('mode must be either png or link')
        unless ($self->{settings}{'mode'} eq 'png' || $self->{settings}{'mode'} eq 'link');

    $self->{transport} = Email::Sender::Transport::SMTP->new({
        host => $self->{settings}{server},
        port => 25,
        ssl => 'starttls',
        sasl_username => $self->{settings}{sender_address},
        sasl_password => $self->{settings}{password},
    });

    return $self;
}


=head2 post

Emails everybody on the recipient list passed to the constructor.

The email subject will be the comic's title, and the body of the email will
contain the description. If mode is "png", the comic will be attached, if
it's "link", the body will also contain a link to the comic.

Parameters:

=over 4

=item * B<@comics> Latest (today's) comic(s).

=back

=cut

sub post {
    my ($self, @comics) = @ARG;

    my @messages;

    foreach my $comic (@comics) {
        LANG: foreach my $language ($comic->languages()) {
            my @recipients;
            eval {
                @recipients = $self->_get_recipients($language);
            } or do {
                push @messages, $self->message($EVAL_ERROR);
                next LANG;
            };

            my $plain_text_part = $self->_build_plain_text_part($comic, $language);
            my ($html_part, $cid) = $self->_build_html_part($comic, $language);
            my $attachment = $self->_build_attachment($comic, $language, $cid);
            my $subject = $comic->{meta_data}->{title}->{$language};
            my $email = $self->_build_email($subject, $plain_text_part, $html_part, $attachment);
            eval {
                sendmail($email, {
                    to => \@recipients,
                    transport => $self->{transport},
                });
            } or do {
                push @messages, $self->message("Error sending $language email, code ",
                    $EVAL_ERROR->code(), q{:}, $EVAL_ERROR->message(), 'for', join q{, },
                    $EVAL_ERROR->recipients);
            };
        }
    }

    return @messages;
}


sub _get_recipients {
    my ($self, $language) = @ARG;

    my $recipients_list = $self->{settings}{'recipient_list'}{$language};
    unless ($recipients_list) {
        croak("no $language recipient list configured");
    }
    my @recipients;
    eval {
        @recipients = File::Slurper::read_lines($recipients_list);
        1;  # so that an empty list is not treated as a read error
    } or do {
        croak("error reading $language recipient list $recipients_list: $EVAL_ERROR");
    };
    @recipients = grep { !/^\s*$/ } @recipients;
    unless (@recipients) {
        croak("$language recipient list is empty");
    }
    s{^\s+|\s+$}{}g foreach @recipients;

    return @recipients;
}


sub _build_plain_text_part {
    my ($self, $comic, $language) = @ARG;

    my $text = "$comic->{meta_data}->{description}->{$language}\n\n";
    if ($self->{settings}->{mode} eq 'link') {
        $text .= $comic->{url}{$language};
    }

    my $part = Email::MIME->create(
        attributes => {
            encoding => 'quoted-printable',
            charset => 'utf-8',
        },
        body => $text,
    );
    $part->content_type_set('text/plain');

    return $part;
}


sub _build_html_part {
    my ($self, $comic, $language) = @ARG;

    my $cid = Email::MessageID->new()->as_string();
    my %lang_codes = $comic->language_codes;

    my $html = <<"HTML";
<!doctype html>
<html lang="$lang_codes{$language}">
<head>
    <meta charset="utf-8"/>
</head>
<body>
    <p>$comic->{meta_data}->{description}->{$language}</p>
HTML

    if ($self->{settings}->{mode} eq 'link') {
        my $url = $comic->{url}{$language};
        my $title = $comic->{meta_data}->{title}->{$language};
        $html .= '    <p><a href="' . $url . '">' . $title . "</a></p>\n";
    }
    else {
        my @transcript = $comic->get_transcript($language);
        my $transcript = encode_entities(join ' ', @transcript);
        $html .= "    <p><img src=\"cid:$cid\" alt=\"$transcript\"/></p>\n";
    }
    $html .= "</body>\n</html>\n";

    my $part = Email::MIME->create(
        attributes => {
            encoding => 'quoted-printable', # makes Email::MIME insert soft line breaks and encode e.g., the = sign
            charset => 'utf-8',
        },
        body => $html,
    );
    $part->content_type_set('text/html');

    return ($part, $cid);
}


sub _build_attachment {
    my ($self, $comic, $language, $cid) = @ARG;

    return if ($self->{settings}->{mode} eq 'link');

    my $attachment = Email::MIME->create(
        attributes => {
            filename => $comic->{pngFile}{$language},
            content_type => 'image/png',
            encoding => 'base64',
        },
        body => File::Slurper::read_binary($comic->{dirName}{$language} . $comic->{pngFile}{$language}),
    );
    $attachment->header_str_set('Content-ID' => "<$cid>");

    return $attachment;
}


sub _build_email {
    my ($self, $subject, $plain_text_part, $html_part, $attachment) = @ARG;

    # HTML is usually more preferred, so it goes last
    my $text_parts = Email::MIME->create(parts => [$plain_text_part, $html_part]);
    $text_parts->content_type_set('multipart/alternative');

    my @parts = ($text_parts);
    push @parts, $attachment if ($attachment);

    my $email = Email::MIME->create(
        header_str => [
            'From' => $self->{settings}->{sender_address},
            'To' => $self->{settings}->{sender_address},
            'Subject' => $subject,
            'Message-ID' => Email::MessageID->new()->in_brackets(),
            # Conveniently Email::MIME adds a Date header with the current
            # time stamp automatically.
        ],
        # If I set parts here (vs after create), I get a different MIME structure.
        # Email::MIME does a bit too much magic under the covers.
        # parts => \@parts,
    );
    $email->content_type_set('multipart/mixed');
    $email->parts_set(\@parts);

    return $email;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Comic module.


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

None.


=head1 INCOMPATIBILITIES

None known.


=head1 BUGS AND LIMITATIONS

None known.


=head1 AUTHOR

Robert Wenner  C<< <rwenner@cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright Robert Wenner. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
See L<perlartistic|perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
