package Comic::Social::Twitter;

use strict;
use warnings;
use utf8;
use Scalar::Util qw/blessed/;
use English '-no_match_vars';
use Carp;
use Readonly;
use String::Util 'trim';
use Net::Twitter;

use Comic::Social::Social;
use base('Comic::Social::Social');


use version; our $VERSION = qv('0.0.3');


# Maximum length of a tweet in characters, as defined by Twitter.
Readonly my $MAX_LEN => 280;


=encoding utf8

=for stopwords Wenner merchantability perlartistic png Ich braue mein eigenes Weil ich kann hashtags


=head1 NAME

Comic::Social::Twitter - tweet a Comic.


=head1 SYNOPSIS

    my $twitter = Comic::Social::Twitter->new({
        consumer_key => '...',
        consumer_secret => '...',
        access_token => '...',
        access_token_secret => '...',
        mode => 'png',
    });
    my $result = $twitter->post($comic);
    print "$result\n";


=head1 DESCRIPTION

Before this module can tweet for you, you need to go to
L<https://developer.twitter.com/apps/> and allow it to post on your
behalf. This will get you the credentials you need above.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::Twitter.

Arguments:

=over 4

=item * B<%settings> hash of settings as below.

=back

The settings hash needs to have these keys:

=over 4

=item * B<$mode> either 'link' or 'png' to tweet either a link to the comic or
    the actual comic png. Defaults to 'png'. 'link' mode requires that the
    comic is uploaded and the URL is available in the Comic. 'png' mode
    requires that a png has been generated and its file name is stored in
    the Comic.

=item * B<$consumer_key> passed to C<Net::Twitter>.

=item * B<$consumer_secret> passed to C<Net::Twitter>.

=item * B<$access_token> passed to C<Net::Twitter>.

=item * B<$access_token_secret> passed to C<Net::Twitter>.

=item * B<...> any other optional arguments to pass to the C<Net::Twitter>
   constructor. (For experts only.)

=back

See L<Net::Twitter> for the meaning of the C<consumer...> and C<access...>
arguments as well as any other possible arguments.

=cut

sub new {
    my ($class, %args) = @ARG;
    my $self = bless{}, $class;

    $self->{mode} = $args{'mode'} || 'png';
    unless ($self->{mode} eq 'png' || $self->{mode} eq 'link') {
        croak($self->message("Unknown twitter mode '$self->{mode}'"));
    }
    delete $args{'mode'}; # to pass only the rest on to Net::Twitter->new

    my %settings = (
        traits => [qw/API::RESTv1_1/],
        ssl => 1,
        %args,
    );
    $self->{twitter} = Net::Twitter->new(%settings);

    return $self;
}


=head2 post

Tweets the given Comic. This code doesn't know or check if the given Comic
is the latest or whether it has already been tweeted. The caller needs to
make sure to pass the right Comic at the right time.

Tweeting the comic means to tweet it in each of its languages. The text for
the tweet will be made from the comic's title, description, and twitter meta
data (i.e., hashtags). Twitter hashtags can be passed in the Comic's
C<twitter -> language> array. If the combined text is too long, it will be
truncated.

For example, if the given Comic has this metadata:

    {
        "title": {
            "english": "Brewing my own beer!",
            "deutsch": "Ich braue mein eigenes Bier!"
        },
        "description": {
            "english": "Because I can!",
            "deutsch": "Weil ich's kann!"
        },
        "twitter": {
            "english": [ "#beer", "#brewing" ],
            "deutsch": [ "#Bier", "#brauen" ]
        }
    }

it will be tweeted in English as "Brewing my own beer! Because I can! #beer
#brewing" and in German as "Ich braue mein eigenes Bier! Weil ich's kann!
#Bier #brauen".

Parameters:

=over 4

=item * B<$comic> Comic to tweet.

=back

Returns any messages from Twitter, separated by newlines.

=cut

sub post {
    my ($self, $comic) = @ARG;

    my @result;
    foreach my $language ($comic->languages()) {
        my @tags = Comic::Social::Social::collect_hashtags($comic, $language, 'twitter');
        my $description = Comic::Social::Social::build_message(
            $MAX_LEN,
            \&_textlen,
            $comic->{meta_data}->{title}->{$language},
            $comic->{meta_data}->{description}->{$language},
            $self->{mode} eq 'link' ? $comic->{url}->{$language} : '',
            @tags,
        );

        my $status;
        eval {
            if ($self->{mode} eq 'link') {
                $status = $self->{twitter}->update($description);
            }
            else {
                $status = $self->{twitter}->update_with_media($description, [
                    "$comic->{dirName}{$language}$comic->{pngFile}{$language}",
                ]);
            }
            push @result, $self->message($status->{text});
        }
        or do {
            my $err = $EVAL_ERROR;
            if (blessed $err && $err->isa('Net::Twitter::Error')) {
                push @result, $self->message("$err->code $err->message ($err->error)");
            }
            else {
                push @result, $self->message("$err (" . ref($err) .')');
            }
        };
    }

    return join "\n", @result;
}


sub _textlen {
    my $text = shift;

    return length $text;
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
