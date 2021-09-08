package Comic::Social::Reddit;

use strict;
use warnings;
use Scalar::Util qw/blessed/;
use English '-no_match_vars';
use Carp;
use Readonly;
use Reddit::Client;

use Comic::Social::Social;
use base('Comic::Social::Social');


use version; our $VERSION = qv('0.0.3');



=encoding utf8

=for stopwords Wenner merchantability perlartistic boolean reddit reddits subreddits hashtags username

=head1 NAME

Comic::Social::Reddit - post a Comic on L<https://reddit.com>.

=head1 SYNOPSIS

    my $twitter = Comic::Social::Reddit->new(
        username => 'yourredditname',
        password => 'secret',
        client_id => '...'
        secret => '...',
    )

=head1 DESCRIPTION

Before this module can post for you to Reddit, you need to go to
L<https://www.reddit.com/prefs/apps> then create an app (script). This will
get you the secret needed to configure this module. See also
L<https://redditclient.readthedocs.io/en/latest/oauth/>.

Unfortunately you cannot use two factor authentication with or the script
won't be able to log in.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::Reddit.

Arguments:

=over 4

=item * B<$username> your reddit user name.

=item * B<$password> your reddit password.

=item * B<$client_id> from your account's apps details page.

=item * B<$secret> from your account's apps details page.

=item * B<...> any other arguments to pass to the C<Net::Reddit> constructor.
   (For experts only.)

=back

See L<Net::Reddit> for the meaning of the C<consumer...> and C<access...>
arguments as well as any other possible arguments.

=cut


sub new {
    my ($class, %args) = @ARG;
    my $self = $class->SUPER::new();

    my %settings = (
        user_agent => 'Comic::Social::Reddit by /u/beercomics',
        %args
    );
    $self->{reddit} = Reddit::Client->new(%settings);

    return $self;
}


=head2 post

Posts the given Comic to the given subreddits and any subreddits mentioned
in the comic's meta data.

For example, if the given Comic has this meta data:

    "reddit": {
        "subreddit": {
            "english": [ "beer", "homebrewing" ],
            "deutsch": [ "bier" ]
        }
    }

then this module will post the English version of the given comic to
L<https://reddit.com/r/beer> and L<https://reddit.com/r/homebrewing> and the
German version to L<https://reddit.com/r/bier>.

If a language has no C<subreddit> setting (in neither the global settings
nor the comic's settings), that comic language won't be posted. For example,
if the comic above was available in English, German, and Spanish, but the
C<reddit> settings don't mention Spanish, the Spanish version won't be
posted.

The comic's C<reddit> configuration can also include a boolean C<use-default>
like this:

    "reddit": {
        "use-default": true
    }

When this is not given or C<true>, the comic will be posted to the default
subreddits from the main configuration and any subreddits defined in the
comic. If C<use-default> is false, the comic won't be posted to the default
subreddits. If the comic sets C<use-defaults> to false and doesn't define
subreddits in its meta data, it won't be posted at all.

Parameters:

=over 4

=item * B<$comic> Comic to post.

=item * B<$default_subreddit> Default subreddit(s), e.g., "/r/comics" or "funny".

=back

Returns any messages from Reddit, separated by newlines.

Note that posting can take a long time, especially on new accounts, as
Reddit may allow you to only post once every ten minutes. This method will
wait and retry until it either managed to post to all requested subreddits
or until it receives an error.

=cut

sub post {
    my ($self, $comic, @default_subreddits) = @ARG;

    my @result;
    foreach my $language ($comic->languages()) {
        my @subreddits;

        # Global default subredit
        my $use_default = $comic->{meta_data}->{reddit}->{'use-default'} // 1;
        if ($use_default) {
            push @subreddits, @default_subreddits;
        }

        # Subreddits specified in the comic
        push @subreddits, _get_subreddits($comic, $language);

        foreach my $subreddit (@subreddits) {
            if ($subreddit) {
                push @result, $self->_post($comic, $language, $subreddit);
            }
        }
    }

    return join "\n", @result;
}


sub _get_subreddits {
    my ($comic, $language) = @ARG;

    my @subreddits;
    my $json = $comic->{meta_data}->{reddit}->{$language}->{subreddit};
    if (defined $json) {
        if (ref($json) eq 'ARRAY') {
            push @subreddits, @{$json};
        }
        else {
            push @subreddits, $json;
        }
    }
    return @subreddits;
}


sub _post {
    my ($self, $comic, $language, $subreddit) = @ARG;

    my $title = "[OC] $comic->{meta_data}->{title}{$language}";
    $subreddit = _normalize_subreddit($subreddit);

    my $message;
    my $full_name = 0;
    while (!$full_name) {
        eval {
            $full_name = $self->{reddit}->submit_link(
                subreddit => $subreddit,
                title => $title,
                url => $comic->{url}{$language},
            );
        }
        or do {
            $message = _wait_for_reddit_limit($comic, $EVAL_ERROR);
            last if ($message);
        }
    }

    if ($message) {
        return "$language: /r/$subreddit: $message";
    }

    $message = "Posted '$title' ($comic->{url}{$language}) to $subreddit";
    if ($full_name) {
        $message .= " ($full_name) at " . $self->{reddit}->get_link($full_name)->{permalink};
    }
    return $message;
}


sub _normalize_subreddit {
    my ($subreddit) = @ARG;

    # Remove leading /r/ and trailing / to make specifiying the subreddit more
    # lenient / user friendly.
    $subreddit =~ s{^/r/}{};
    $subreddit =~ s{/$}{};
    return $subreddit;
}


sub _wait_for_reddit_limit {
    my ($comic, $error) = @ARG;

    if ($error =~ m{\btry again in (\d+) (minutes?|seconds?)}i) {
        my ($count, $unit) = ($1, $2);
        if ($unit =~ m/minutes?/i) {
            Readonly my $SECS_PER_MINUTE => 60;
            $count *= $SECS_PER_MINUTE;
        }
        _sleep($count);
    }
    elsif ($error =~ m{already been submitted}i) {
        chomp $error;
        return $error;
    }
    elsif ($error) {
        $comic->keel_over("Don't know what reddit complains about: '$error'");
    }

    return '';
}


sub _sleep {
    # uncoverable subroutine
    sleep @ARG; # uncoverable statement
    return; # uncoverable statement
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
