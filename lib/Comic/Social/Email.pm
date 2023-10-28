package Comic::Social::Email;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';

use version; our $VERSION = qv('0.0.3');

use Comic::Social::Social;
use base('Comic::Social::Social');

use File::Slurper;
use Email::Stuffer;
use Email::Sender::Transport::SMTP;


=encoding utf8

=for stopwords Wenner merchantability perlartistic Uploader Uploaders


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

The C<mode> specifies whether to send the comic's PNG image ("png") as an
attachment or just a link to the comic ("html"). Defaults to "png".

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

    my $me = ref $self;
    my @messages;
    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            my $recipients_list = $self->{settings}{'recipient_list'}{$language};
            unless ($recipients_list) {
                push @messages, "$me: no $language recipient list configured";
                next;
            }
            my @recipients;
            eval {
                @recipients = File::Slurper::read_lines($recipients_list);
                1;  # so that an empty list is not treated as an error
            } or do {
                push @messages, "$me: error reading $language recipient list $recipients_list: $EVAL_ERROR";
                next;
            };
            unless (@recipients) {
                push @messages, "$me: $language recipient list is empty";
                next;
            }

            foreach my $recipient (@recipients) {
                $recipient =~ s/^\s+//;
                $recipient =~ s/\s+$//;
                next unless ($recipient);

                my $transport = Email::Sender::Transport::SMTP->new({
                    host => $self->{settings}{server},
                    port => 25,
                    ssl => 'starttls',
                    sasl_username => $self->{settings}{sender_address},
                    sasl_password => $self->{settings}{password},
                });
                my $stuffer = Email::Stuffer->transport($transport);

                $stuffer
                    ->from($self->{settings}{sender_address})
                    ->to($recipient);

                my $title = $comic->{meta_data}->{title}{$language};
                # Automatically encodes subjects with non-ascii characters
                $stuffer->subject($title);

                my $description = $comic->{meta_data}->{description}->{$language};
                my $plain_body = "$description\n\n";
                my $html_body = "<p>$description</p>\n\n";

                if ($self->{settings}{mode} eq 'link') {
                    my $link = $comic->{url}{$language};
                    $plain_body .= "$link\n";
                    $html_body .= "<p><a href=\"$link\">$title</a></p>\n";
                }
                $stuffer
                    ->text_body($plain_body)
                    ->html_body($html_body);

                if ($self->{settings}{mode} eq 'png') {
                    my $path = $comic->{dirName}{$language} . $comic->{pngFile}{$language};
                    $stuffer->attach_file($path);
                }

                eval {
                    $stuffer->send_or_die();
                } or do {
                    push @messages, "$me: Error sending $language email to $recipient: $EVAL_ERROR";
                };
            }
        }
    }

    return @messages;
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

Copyright (c) 2023, Robert Wenner C<< <rwenner@cpan.org> >>.
All rights reserved.

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
