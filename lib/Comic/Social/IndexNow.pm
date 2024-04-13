package Comic::Social::IndexNow;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use JSON;
use HTTP::Tiny;

use version; our $VERSION = qv('0.0.3');

use Comic::Social::Social;
use base('Comic::Social::Social');

use Readonly;
Readonly my $MIN_KEY_LEN => 8;
Readonly my $MAX_KEY_LEN => 128;
Readonly my $URL => 'https://api.indexnow.org/indexnow';


=encoding utf8

=for stopwords Wenner merchantability perlartistic uuid Uploader Uploaders


=head1 NAME

Comic::Social::IndexNow - notify search engines that support "index now" of
new content.

=head1 SYNOPSIS

    my $index_now = Comic::Social::IndexNow->new({
        'key' => 'my somehwat secret key',
    });

=head1 DESCRIPTION

Notifies a search engine that supports the L<index now|https://indexnow.org>
protocol. This may or may not be only L<https://bing.com>.

Technically, this could be an Uploader module as well, but Uploaders should
be independent of each other and C<IndexNow> depends on whatever module
actually updates the website. Hence it fits better as a social media module
where that dependency is normal.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::IndexNow.

Parameters:

=over 4

=item * B<%settings> Hash reference with settings, as below.

=back

The passed settings must be a hash reference like this:

    {
        "key" => "my somewhat secret key",
        "url" => "https://indexnow.org/indexnow",
    }

The mandatory C<key> is a key you generate yourself, like a UUID. You need to
put that key in file in the web root of your domain; see the L<https://indexnow.org>
documentation.

The optional C<url> is the full URL (including the protocol and path, but
excluding the query string) to use for notifications. Defaults to
L<https://api.indexnow.org/indexnow> if not given.

=cut

sub new {
    my $class = shift @ARG;
    my $self = bless{}, $class;

    $self->_croak('settings hash missing') unless(@ARG);
    $self->_croak('settings must be a hash') unless (@ARG % 2 == 0);
    $self->{settings} = {@ARG};

    $self->_croak('key missing') unless ($self->{settings}{'key'});
    $self->_croak('key is too short') if (length($self->{settings}{'key'}) < $MIN_KEY_LEN);
    $self->_croak('key is too long') if (length($self->{settings}{'key'}) > $MAX_KEY_LEN);
    # I cannot use a character class like [:alnum:] here because that also
    # matches umlauts, and those are not allowed in the key.
    ## no critic(RegularExpressions::ProhibitEnumeratedClasses)
    $self->_croak('key has invalid characters') if ($self->{settings}{'key'} !~ m{^[a-zA-Z0-9-]+$});
    ## use critic

    $self->{settings}{'url'} = $URL unless ($self->{settings}{'url'});
    if ($self->{settings}{'url'} =~ m{[?]}) {
        $self->_croak('url cannot contain a query string');
    }
    if ($self->{settings}{'url'} !~ m{^https?://}) {
        $self->{settings}{'url'} = 'https://' . $self->{settings}{'url'};
    }

    return $self;
}


=head2 post

Notifies the search engine of the new web pages.

Parameters:

=over 4

=item * B<@comics> Latest (today's) comic(s).

=back

=cut

sub post {
    my ($self, @comics) = @ARG;

    my $http = HTTP::Tiny->new();
    my @messages;

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            my %payload = (
                'host' => $comic->{settings}->{Domains}{$language},
                'key' => $self->{settings}{'key'},
                # No need to encode the URLs when they are passed as form data.
                'urlList' => [ $comic->{url}->{$language} ],
            );
            my $json = encode_json(\%payload);
            my %options = (
                'headers' => {
                    'Content-Type' => 'application/json; charset=utf-8',
                },
                'content' => $json,
            );
            push @messages, $self->message("submitting $comic->{url}->{$language}");
            my $response = $http->post($self->{settings}{'url'}, \%options);
            push @messages, $self->message("$response->{status} $response->{reason}");
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
