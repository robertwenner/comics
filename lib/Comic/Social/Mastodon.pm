package Comic::Social::Mastodon;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use String::Util 'trim';
use Readonly;
use Net::IDN::Encode;
use HTTP::Tiny;
use File::Slurper;
use JSON;

use Comic::Social::Social;
use base('Comic::Social::Social');


use version; our $VERSION = qv('0.0.3');


# Maximum length of a toot in characters, as defined by Mastodon.
Readonly my $MAX_LEN => 500;
# HTTP::Tiny reports e.g., DNS errors with code 599.
Readonly my $HTTP_TINY_ERROR => 599;


=encoding utf8

=for stopwords Wenner merchantability perlartistic html Prost auf mich png


=head1 NAME

Comic::Social::Mastodon - toot / post a Comic.


=head1 SYNOPSIS

    my $mastodon = Comic::Social::Mastodon->new({
        'client-key' => '...',
        'client-secret' => '...',
        'access-token' => '...',
        'mode' => 'html',
    });
    my $result = $mastodon->post($comic);
    print "$result\n";


=head1 DESCRIPTION

Posts a comic to Mastodon.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::Mastodon.

Arguments:

=over 4

=item * B<%settings> hash of settings as below.

=back

The settings hash needs to have these keys:

=over 4

=item * B<access-token> Mastodon access token from the application's page in
    Mastodon. This assumes that the authorization token is valid until revoked.
    I didn't find anything on how long the token is valid. So far, mine works
    for a month.

=item * B<instance> Name of the Mastodon instance to toot to.

=item * B<mode> Either 'png' or 'html': whether to post the comic's image or
    a link to the comic.

=item * B<visibility> optional visibility (e.g., "public" or "private"),
    defaults to the visibility configured in the account settings.

=back

This module should work with Mastodon API versions 3.1.3 or later.

=cut

sub new {
    my ($class, %args) = @ARG;
    my $self = bless{}, $class;

    $self->{me} = ref $self;
    croak("$self->{me}: configuration missing") unless (%args);
    croak("$self->{me}: instance missing") unless ($args{'instance'});
    croak("$self->{me}: instance name cannot contain slashes") if ($args{'instance'} =~ m{/});
    croak("$self->{me}: access_token missing") unless ($args{'access_token'});
    croak("$self->{me}: mode missing, use png or html") unless ($args{'mode'});
    unless ($args{'mode'} eq 'png' || $args{'mode'} eq 'html') {
        croak("$self->{me}: unknown posting mode '$args{'mode'}'");
    }

    $self->{settings} = \%args;
    $self->{settings}->{instance} = Net::IDN::Encode::domain_to_ascii($self->{settings}->{instance});

    return $self;
}


=head2 post

Toots / posts the given Comic. This code doesn't know or check if the given
Comic is the latest or whether it has already been posted. The caller needs
to make sure to pass the right Comic at the right time.

Tooting the comic means to toot / post it in each of its languages. The text
for the toot will be made from the comic's title, description, and Twitter
hash tags meta data. Hashtags can be passed in the Comic's C<twitter ->
language> array.

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
        "twitter": {
            "english": [ "#beer", "#brewing" ],
            "deutsch": [ "#Bier", "#brauen" ]
        }
    }

it will be tooted in English as "Cheers to me #beer #brewing" and in German
as "Prost auf mich #Bier #brauen".

Parameters:

=over 4

=item * B<$comic> Comic to post.

=back

Returns any messages from Mastodon, separated by newlines.

=cut

sub post {
    my ($self, $comic) = @ARG;

    $self->{http} = HTTP::Tiny->new(verify_SSL => 1);

    # Get an authentication token from client id and client secret.
    #
    # curl -X POST \
    #   --form 'client_id=...' \
    #   --form 'client_secret=...' \
    #   --form 'redirect_uri=urn:ietf:wg:oauth:2.0:oob' \
    #   --form 'grant_type=client_credentials' \
    #   --form 'scope=write:media write:statuses' \
    #   "https://$instance/oauth/token" \
    # | jq .access_token
    #
    # See https://docs.joinmastodon.org/client/token/

    my %language_codes = $comic->language_codes();
    my @result;
    foreach my $language ($comic->languages()) {
        my $description = _build_message($comic, $language, $self->{settings}->{mode});

        my $media_id;
        if ($self->{settings}->{mode} eq 'png') {
            my @messages;
            ($media_id, @messages) = $self->_upload_media(
                "$comic->{dirName}{$language}/$comic->{pngFile}{$language}",
                $description,
            );
            push @result, @messages;
            unless ($media_id) {
                # Didn't get a media id for whatever reason. If the server is
                # down or premissions are not correct, the next call will
                # fail as well. Try if Mastodon just doesn't like that image
                # for some reason but accepts a link.
                push @result, "$self->{me}: posting comic link instead";
                $description = _build_message($comic, $language, 'html');
            }
        }
        push @result, $self->_post_status($description, $language_codes{$language}, $media_id);
    }

    return join "\n", @result;
}


sub _build_message {
    my ($comic, $language, $mode) = @ARG;

    my @tags = Comic::Social::Social::collect_hashtags($comic, $language, 'mastodon');
    return Comic::Social::Social::build_message(
        $MAX_LEN,
        \&_textlen,
        $comic->{meta_data}->{title}->{$language},
        $comic->{meta_data}->{description}->{$language},
        $mode eq 'html' ? $comic->{url}->{$language} : '',
        @tags,
    );
}


sub _textlen {
    my ($text) = @ARG;

    return 0 unless ($text);

    # A link always counts as 23 characters; see https://docs.joinmastodon.org/user/posting/#links
    $text =~ s{https?://\S+}{12345678901234567890123}mg;
    # Mentioning someone does not count the instance name against the character limit, only the
    # local name; see https://docs.joinmastodon.org/user/posting/#mentions
    $text =~ s{(@[^@\s]+)@\S+}{$1}mg;

    return length $text;
}


sub _upload_media {
    my ($self, $local_file, $description) = @ARG;

    # Upload media to refer to it when posting a status.
    #
    # curl --silent -X POST \
    #   --header "Authorization: Bearer $token" \
    #   --form 'file=@some.png' \
    #   --form 'description=...' \
    #   "https://$instance/api/v2/media" \
    # | jq .id
    #
    # See https://docs.joinmastodon.org/methods/media/#v2

    my $url = "https://$self->{settings}->{instance}/api/v2/media";
    my %form_data = (
        'file' => File::Slurper::read_binary($local_file),
        'description' => $description,
    );
    my %options = (
        'headers' => {
            'Authorization' => "Bearer $self->{settings}->{access_token}",
        },
    );

    my $reply = $self->{http}->post_form($url, \%form_data, \%options);

    my $id;
    if ($reply->{success}) {
        return ($id, "$self->{me}: error: no content in media reply") unless ($reply->{content});
        my $parsed;
        eval {
            $parsed = decode_json($reply->{content});
        } or do {
            return ($id, "$self->{me}: cannot parse media JSON reply: $EVAL_ERROR");
        };
        $id = $parsed->{id};
        if ($id) {
            return ($id, "$self->{me} uploaded $local_file, returned media id is $id");
        }
        return ($id, "$self->{me}: uploaded $local_file but got no media id");
    }
    return ($id, $self->_mastodon_error($reply));
}


sub _post_status {
    my ($self, $description, $lang_code, $media_id) = @ARG;

    # Post a status, optionally referring to previously uploaded media.
    #
    # curl -X POST \
    #   --header "Authorization: Bearer $token" \
    #   --form 'status=...' \
    #   --form "media_ids[]=$id" \
    #   --form 'language=de' \
    #   --form 'visibility=private' \
    #   "https://$instance/api/v1/statuses"
    #
    # See https://docs.joinmastodon.org/methods/statuses/#create
    my $url = "https://$self->{settings}->{instance}/api/v1/statuses";
    my %form_data = (
        'status' => $description,
        'language' => $lang_code,
    );
    if ($self->{settings}->{visibility}) {
        $form_data{'visibility'} = $self->{settings}->{visibility};
    }
    if ($media_id) {
       $form_data{'media_ids[]'} = $media_id;
    }
    my %options = (
        'headers' => {
            'Authorization' => "Bearer $self->{settings}->{access_token}",
        },
    );

    my $reply = $self->{http}->post_form($url, \%form_data, \%options);

    if ($reply->{success}) {
        return "$self->{me}: error: no content in status reply" unless ($reply->{content});
        my $parsed;
        eval {
            $parsed = decode_json($reply->{content});
        } or do {
            return "$self->{me}: cannot parse status JSON reply: $EVAL_ERROR";
        };
        my $id = $parsed->{id} || '(no id)';
        my $timestamp = $parsed->{created_at} || '(no timestamp)';
        my $language = $parsed->{language} || '(no language)';
        my $content = $parsed->{content} || '(no content)';
        my $result = "$self->{me} posted on $timestamp in $language with id $id: $content";
        if ($parsed->{media_attachments}) {
            my $attachment = $parsed->{media_attachments}[0];
            if ($attachment) {
                $result .= " referring $attachment->{type} id $attachment->{id}";
            }
        }
        return $result;
    }
    return $self->_mastodon_error($reply);
}


sub _mastodon_error {
    my ($self, $reply) = @ARG;

    my $http_details = "$self->{me}: ";
    if ($reply->{status} == $HTTP_TINY_ERROR) {
        $http_details .= $reply->{content};
    }
    else {
        $http_details .= "HTTP $reply->{status} $reply->{reason} -- $reply->{content}";
    }
    return $http_details;
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

Copyright (c) 2022 - 2023, Robert Wenner C<< <rwenner@cpan.org> >>.
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
