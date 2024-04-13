package Comic::Social::Bluesky;

use strict;
use warnings;
use utf8;
use Encode;
use Net::IDN::Encode;
use English '-no_match_vars';
use Carp;
use Readonly;
# As of March 2024, https://metacpan.org/pod/At did not support facets, needed for links and tags.
# Hence do the few HTTP requests manually.
use HTTP::Tiny;
use File::Slurper;
use JSON;

use Comic::Social::Social;
use base('Comic::Social::Social');


use version; our $VERSION = qv('0.0.3');


# Maximum length of a message in characters, as defined by Bluesky.
# https://github.com/bluesky-social/atproto/blob/2f62faab6fd7ef7e37c4fe6b633664fce0a1e6cf/lexicons/app/bsky/feed/post.json#L13
Readonly my $MAX_LEN => 3000;
# HTTP::Tiny reports e.g., DNS errors with code 599.
Readonly my $HTTP_TINY_ERROR => 599;


=encoding utf8

=for stopwords Wenner merchantability perlartistic Prost auf mich png Bluesky


=head1 NAME

Comic::Social::Bluesky - post a Comic to Bluesky.


=head1 SYNOPSIS

    my $bluesky= Comic::Social::Bluesky->new({
        'client-key' => '...',
        'client-secret' => '...',
        'mode' => 'link',
    });
    my $result = $bluesky->post($comic);
    print "$result\n";


=head1 DESCRIPTION

Posts a comic to Bluesky.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::Bluesky.

Arguments:

=over 4

=item * B<%settings> hash of settings as below.

=back

The settings hash needs to have these keys:

=over 4

=item * B<username> Bluesky user name.

=item * B<password> The (app) password to log in.

=item * B<mode> Either 'png' or 'link': whether to post the comic's image or
    a link to the comic.

=back

=cut

sub new {
    my ($class, %args) = @ARG;
    my $self = bless{}, $class;

    croak($self->message('configuration missing')) unless (%args);
    croak($self->message('username missing')) unless ($args{'username'});
    croak($self->message('password missing')) unless ($args{'password'});
    croak($self->message('mode missing, use png or link')) unless ($args{'mode'});
    unless ($args{'mode'} eq 'png' || $args{'mode'} eq 'link') {
        croak($self->message("unknown posting mode '$args{'mode'}', use png or link"));
    }

    $self->{settings} = \%args;
    $self->{settings}->{service} ||= 'bsky.social';
    # Remove trailing slash so that we know how to build URLs later.
    $self->{settings}->{service} =~ s{/$}{}x;
    # Encode international domain names; remove protocol first
    $self->{settings}->{service} =~ s{^https?://}{}x;
    $self->{settings}->{service} = Net::IDN::Encode::domain_to_ascii($self->{settings}->{service});
    # Enforce HTTPS, we're sending a password.
    $self->{settings}->{service} = "https://$self->{settings}->{service}";

    return $self;
}


=head2 post

Posts the given Comic in each of its languages. This code doesn't know or check
if the given Comic is the latest or whether it has already been posted. The
caller needs to make sure to pass the right Comic at the right time.

The text for the message will be made from the comic's title, description, and Bluesky
hash tags meta data. Hashtags can be passed in the Comic's C<bluesky.language>
array.

For example, if the given Comic has this meta data:

    {
        "title": {
            "english": "Cheers",
            "deutsch": "Prost"
        },
        "description": {
            "english": "to me",
            "deutsch": "auf mich"
        },
        "bluesky": {
            "english": [ "#beer", "#brewing" ],
            "deutsch": [ "#Bier", "#brauen" ]
        }
    }

it will be posted in English as "Cheers to me #beer #brewing" and in German
as "Prost auf mich #Bier #brauen".

Parameters:

=over 4

=item * B<$comic> Comic to post.

=back

Returns any messages from Bluesky, separated by newlines.

=cut

sub post {
    my ($self, $comic) = @ARG;

    # https://docs.bsky.app/docs/get-started
    # Cache token between post calls (different comics in different languages on the same day)
    unless ($self->{http}) {
        $self->{http} = HTTP::Tiny->new(verify_SSL => 1);
        my $error = $self->_login();
        if ($error) {
            $self->{http} = undef;
            return $self->message($error);
        }
    }

    my @result;
    foreach my $language ($comic->languages()) {
        if ($self->{settings}->{mode} eq 'png') {
            my $error = $self->_upload_png($comic, $language);
            if ($error) {
                push @result, $self->message($error);
            }
        }
        push @result, $self->message($self->_post($comic, $language));
        # Clear the blob id, so that we don't post the same image again when uploading another
        # one fails for some reason; fall back to link posting instead.
        $self->{blob_id} = undef;
    }

    return join "\n", @result;
}


sub _login {
    my ($self) = @ARG;

    my $error_prefix = "Error logging in to $self->{settings}->{service}";
    my $url = "$self->{settings}->{service}/xrpc/com.atproto.server.createSession";
    my %credentials = (
        'identifier' => $self->{settings}->{username},
        'password' => $self->{settings}->{password},
    );
    my $reply = $self->{http}->request('POST', $url, {
        'content' => encode_json(\%credentials),
        'headers' => {
            'Content-Type' => 'application/json',
        },
    });

    my ($error, $content) = _handle($error_prefix, $reply);
    return $error if ($error);
    $self->{access_token} = $content->{accessJwt};
    $self->{did} = $content->{did};
    return;
}


sub _handle {
    my ($error_prefix, $reply) = @ARG;

    if ($reply->{status} == $HTTP_TINY_ERROR) {
        return "$error_prefix: $reply->{content}";
    }
    unless ($reply->{success}) {
        return "$error_prefix: HTTP error $reply->{status} on login: $reply->{reason}";
    }

    my $content;
    eval {
        $content = decode_json($reply->{content});
    } or do {
        return "$error_prefix: bad JSON received on login";
    };
    return (undef, $content);
}


sub _upload_png {
    my ($self, $comic, $language) = @ARG;

    my $error_prefix = "error uploading png for $comic->{meta_data}->{title}->{$language}";
    my $url = "$self->{settings}->{service}/xrpc/com.atproto.repo.uploadBlob";
    my %headers = (
        'Authorization' => "Bearer $self->{access_token}",
    );
    my $png_file_path = $comic->{dirName}{$language} . $comic->{pngFile}{$language};
    my $reply = $self->{http}->request('POST', $url, {
         'content' => File::Slurper::read_binary($png_file_path),
         'headers' => \%headers,
    });

    my ($error, $content) = _handle($error_prefix, $reply);
    return $error if ($error);
    $self->{blob_id} = $content->{blob};
    return;
}


sub _post {
    # https://docs.bsky.app/docs/tutorials/creating-a-post
    my ($self, $comic, $language) = @ARG;

    my %language_codes = $comic->language_codes();
    my $mode = $self->{blob_id} ? 'png' : 'link';
    my $description = _build_message($comic, $language, $mode);
    if ($self->{blob_id}) {
        $description->{embed} = {
            # The variable is really named $type. :-/
            ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
            '$type' => 'app.bsky.embed.images',
            images => [{
                alt => $comic->{meta_data}->{description}->{$language},
                image => $self->{blob_id},
                aspectRatio => {
                    width => $comic->{width}->{$language},
                    height => $comic->{height}->{$language},
                },
            }],
        };
    }

    my $error_prefix = "error posting $comic->{meta_data}->{title}->{$language}";
    my $url = "$self->{settings}->{service}/xrpc/com.atproto.repo.createRecord";
    my %headers = (
        'Authorization' => "Bearer $self->{access_token}",
        'Content-Type' => 'application/json',
    );
    my %payload = (
        'repo' => $self->{did},
        'collection' => 'app.bsky.feed.post',
        'record' => {
            %{$description},
            'createdAt' => $comic->{rfc3339pubDate},
            'langs' => [ $language_codes{$language} ],
        },
    );

    my $reply = $self->{http}->request('POST', $url, {
        'content' => encode_json(\%payload),
        'headers' => \%headers,
    });

    my ($error, $content) = _handle($error_prefix, $reply);
    return $error if ($error);
    return "posted $comic->{meta_data}->{title}->{$language} $mode";
}


sub _build_message {
    my ($comic, $language, $mode, $feature) = @ARG;

    # https://github.com/bluesky-social/atproto/blob/2f62faab6fd7ef7e37c4fe6b633664fce0a1e6cf/lexicons/app/bsky/feed/post.json#L50
    my @tags = Comic::Social::Social::collect_hashtags($comic, $language, 'bluesky');
    my $text = Comic::Social::Social::build_message(
        $MAX_LEN,
        \&_textlen,
        $comic->{meta_data}->{title}->{$language},
        $comic->{meta_data}->{description}->{$language},
        $mode eq 'link' ? $comic->{url}->{$language} : '',
        @tags,
    );
    my $encoded = Encode::encode('UTF-8', $text);

    my @facets;
    if ($mode eq 'link') {
        push @facets, _build_facets($encoded, $comic->{url}->{$language}, 'link', 'uri');
    }
    foreach my $tag (@tags) {
        my $type = $tag =~ m{^@}x ? 'mention' : 'tag';
        push @facets, _build_facets($encoded, $tag, $type, 'tag');
    }

    my $message = {
        text => $text,
    };
    $message->{facets} = \@facets if (@facets);
    return $message;

}


sub _textlen {
    my ($text) = @ARG;

    return 0 unless ($text);
    # We need to count bytes, not characters; see the examples in the end of the mentions and
    # links section at https://docs.bsky.app/docs/tutorials/creating-a-post#mentions-and-links
    return length(Encode::encode('UTF-8', $text));
}


sub _build_facets {
    # https://docs.bsky.app/docs/advanced-guides/post-richtext
    my ($message, $facet, $type, $feature) = @ARG;

    my $start = index $message, Encode::encode('UTF-8', $facet);
    my $length = _textlen($facet);
    $facet =~ s{^[@#]}{}x;
    return {
        index => {
            byteStart => $start,
            byteEnd => $start + $length,
        },
        features => [{
            # Parameter name here is really $type with a dollar sign, we need single quotes,
            # don't try to expand $type on the left side of the fat arrow.
            ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
            '$type' => "app.bsky.richtext.facet#$type",
            $feature => $facet,
        }],
    };
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
