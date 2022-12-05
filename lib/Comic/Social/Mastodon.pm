package Comic::Social::Mastodon;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use String::Util 'trim';
use Readonly;
use Mastodon::Client;

use Comic::Social::Social;
use base('Comic::Social::Social');


use version; our $VERSION = qv('0.0.3');


# Maximum length of a toot in characters, as defined by Mastodon.
Readonly my $MAX_LEN => 500;

# HTTP error code to retry
Readonly my $RETRY_HTTP_CODE => 400;


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

=item * B<client-key> Mastodon client key from the application's page in Mastodon.

=item * B<client-secret> Mastodon client secret from the application's page in Mastodon.

=item * B<access-token> Mastodon access token from the application's page in Mastodon.

=item * B<instance> Name of the Mastodon instance to toot to, defaults to whatever
    L<Mastodon::Client> uses as default.

=item * B<mode> Either 'png' or 'html': whether to post the comic's image or
    a link to the comic.

=item * B<retry400> How often to retry HTTP 400 errors.

=back

Any additional arguments are passed on to the Mastodon client; see
L<Mastodon::Client> for supported arguments.

=cut

sub new {
    my ($class, %args) = @ARG;
    my $self = bless{}, $class;

    my $me = ref $self;
    croak("$me: configuration missing") unless (%args);
    croak("$me: client_key missing") unless ($args{'client_key'});
    croak("$me: client_secret missing") unless ($args{'client_secret'});
    croak("$me: access_token missing") unless ($args{'access_token'});
    croak("$me: cannot specify client_id, use client_key instead") if ($args{'client_id'});

    $self->{retry400} = $args{'retry400'} || 0;
    croak("$me: retry400 must be the number of retries") if ($self->{'retry400'} !~ m/^\d+$/);

    $self->{mode} = $args{'mode'} || 'png';
    unless ($self->{mode} eq 'png' || $self->{mode} eq 'html') {
        croak("$me: unknown mastodon mode '$self->{mode}'");
    }
    delete $args{'mode'}; # to pass only the rest on to Mastodon::Client's constructor

    my %settings = (
        'name' => "$me $VERSION",
        'website' => 'https://github.com/robertwenner/comics',
        'coerce_entities' => 1,
        # Mastodon's application page calls it the client key, but Mastodon::Client
        # uses client-id, so keep the lingo close to what the end user sees on the
        # Mastodon page and translate it here.
        'client_id' => delete $args{'client_key'},
        %args,
    );
    $self->{mastodon} = Mastodon::Client->new(%settings);

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

    my @result;
    foreach my $language ($comic->languages()) {
        my @tags = Comic::Social::Social::collect_hashtags($comic, $language, 'mastodon');
        my $description = Comic::Social::Social::build_message(
            $MAX_LEN,
            \&_textlen,
            $comic->{meta_data}->{title}->{$language},
            $comic->{meta_data}->{description}->{$language},
            $self->{mode} eq 'html' ? $comic->{url}->{$language} : '',
            @tags,
        );

        my $tries = 1;
        my $need_to_retry = 0;
        do {
            eval {
                $need_to_retry = 0;
                push @result, $self->_toot($comic, $language, $description);
           }
           or do {
               my ($should_retry, @errors) = $self->_mastodon_error($tries, $EVAL_ERROR);
               $need_to_retry = $should_retry;
               push @result, @errors;
           };
           $tries++;
        }
        while ($need_to_retry);
    }

    return join "\n", @result;
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


sub _toot {
    my ($self, $comic, $language, $description) = @ARG;

    my $me = ref $self;
    my %params;
    if ($self->{mode} eq 'png') {
        my $attachment = $self->{mastodon}->upload_media(
            "$comic->{dirName}{$language}/$comic->{pngFile}{$language}",
            {
                'description' => $description,
            },
        );
        $params{'media_ids'} = [$attachment->{id}];
    }

    my $result = $self->{mastodon}->post_status($description, \%params);
    return "$me posted: " . $result->content;
}


sub _mastodon_error {
    my ($self, $tries, $eval_error) = @ARG;

    my $me = ref $self;
    my $need_to_retry = 0;
    my @result;
    # May not have details (server reply) when it didn't even talk to a
    # Mastodon server yet, like when a local file to upload was not found.
    my $details = $self->{mastodon}->latest_response();
    # $eval_error is always set or this function wouldn't get called, but
    # Devel::Cover doesn't see that, and the uncoverable code comments are
    # too finicky.
    $details = $eval_error unless ($details);
    if (ref $details eq 'HTTP::Response') {
        my $code = $details->code;
        # If there is an actual HTTP response, use it's body as well, to get
        # more error detail than what Mastodon::Client reports. Ignore
        # $EVAL_ERROR in that case, as it certainly has less useful
        # information and may even add a noisy stack trace.
        $details = $details->status_line . ' ' . $details->content;
        push @result, "$me error: $details";
        if ($code == $RETRY_HTTP_CODE) {
            $need_to_retry = $tries <= $self->{retry400};
            push @result, "Retry $tries of $self->{retry400}" if ($need_to_retry);
        }
    }
    else {
        push @result, "$me error: $details";
    }

    return ($need_to_retry, @result);
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

Copyright (c) 2022, Robert Wenner C<< <rwenner@cpan.org> >>.
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
