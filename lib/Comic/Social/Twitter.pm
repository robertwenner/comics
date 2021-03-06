package Comic::Social::Twitter;

use strict;
use warnings;
use Scalar::Util qw/blessed/;
use English '-no_match_vars';
use Carp;
use Readonly;

use Net::Twitter;

use version; our $VERSION = qv('0.0.3');

# Maximum length of a tweet in characters, as defined by Twitter.
Readonly my $MAX_LEN => 280;


=encoding utf8

=for stopwords Wenner merchantability perlartistic html png Ich braue mein eigenes Weil ich kann hashtags

=head1 NAME

Comic::Social::Twitter - tweet the a Comic.

=head1 SYNOPSIS

    my $twitter = Comic::Social::Twitter->new(
        consumer_key => '...',
        consumer_secret => '...',
        access_token => '...',
        access_token_secret => '...',
        mode => 'png'
    );
    my $comic = ...
    my $result = $comic->tweet('/c/comics');
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

=item * B<$mode> either 'html' or 'png' to tweet either a link to the comic or
    the actual comic png. Defaults to 'png'.

=item * B<$consumer_key> passed to C<Net::Twitter>.

=item * B<$consumer_secret> passed to C<Net::Twitter>.

=item * B<$access_tokeny> passed to C<Net::Twitter>.

=item * B<$access_token_secret> passed to C<Net::Twitter>.

=item * B<...> any other arguments to pass to the C<Net::Twitter> constructor.
   (For experts only.)

=back

See L<Net::Twitter> for the meaning of the C<consumer...> and C<access...>
arguments as well as any other possible arguments.

=cut


sub new {
    my ($class, %args) = @ARG;
    my $self = bless{}, $class;

    $self->{mode} = $args{'mode'} || 'png';
    unless ($self->{mode} eq 'png' || $self->{mode} eq 'html') {
        croak("Unknown twitter mode '$self->{mode}'");
    }
    $args{'mode'} = undef;

    my %settings = (
        traits => [qw/API::RESTv1_1/],
        ssl => 1,
        %args,
    );
    $self->{twitter} = Net::Twitter->new(%settings);

    return $self;
}


=head2 tweet

Tweets the given Comic. This code doesn't know or check if the given Comic
is the latest or whether it has already been tweeted. The caller needs to
make sure to pass the right Comic at the right time.

Tweeting the comic means to tweet it in each of its languages. The text for
the tweet will be made from the comic's title, description, and twitter meta
data (i.e., hashtags). Twitter hashtags can be passed in the Comic's
C<twitter -> language> array. If the combined text is too long, it will be
truncated.

For example, if the given Comic has this meta data:

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

it will be tweeted in English with as "Brewing my own beer! Because I can!
#beer #brewing" and in German as "Ich braue mein eigenes Bier! Weil ich's
kann! #Bier #brauen".

Parameters:

=over 4

=item * B<$comic> Comic to tweet.

=back

Returns any messages from Twitter, separated by newlines.

=cut

sub tweet {
    my ($self, $comic) = @ARG;

    my @result;
    foreach my $language ($comic->languages()) {
        my $description = $comic->{meta_data}->{description}->{$language};
        my $tags = '';
        if ($comic->{meta_data}->{twitter}->{$language}) {
            $tags = join(' ', @{$comic->{meta_data}->{twitter}->{$language}}) . ' ';
        }
        my $text = _shorten("$tags$description");

        my $status;
        eval {
            if ($self->{mode} eq 'html') {
                $status = $self->{twitter}->update($comic->{url}{$language});
            }
            else {
                $status = $self->{twitter}->update_with_media($text, [
                    "$comic->{whereTo}{$language}/$comic->{pngFile}{$language}"
                ]);
            }
        }
        or do {
            my $err = $EVAL_ERROR;
            croak $err unless blessed $err && $err->isa('Net::Twitter::Error');
            croak $err->code, ': ', $err->message, "\n", $err->error, "\n";
        };
        push @result, $status->{text};
    }

    return join "\n", @result;
}


sub _shorten {
    my $text = shift;

    return substr $text, 0, $MAX_LEN;
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

Copyright (c) 2015 - 2021, Robert Wenner C<< <rwenner@cpan.org> >>.
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
