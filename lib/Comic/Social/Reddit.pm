package Comic::Social::Reddit;

use strict;
use warnings;
use utf8;
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

    my $reddit = Comic::Social::Reddit->new(
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

Unfortunately you cannot use Reddit's two factor authentication or the
script won't be able to log in.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::Reddit.

Arguments:

=over 4

=item * B<$username> your reddit user name.

=item * B<$password> your reddit password.

=item * B<$client_id> from your account's apps details page.

=item * B<$secret> from your account's apps details page.

=item * B<$default_subreddit> Optional default subreddit(s), e.g.,
    "/r/comics" or "funny". This is language-independent. If there is no
    default subreddit and the comic doesn't specify subreddits either, it
    won't be posted to Reddit at all.

=item * B<client_settings> any other arguments to pass to the L<Reddit::Client>
    constructor. (For experts only.)

=item * B<title_prefix> Optional prefix to use in the post's title. Will be
    placed in front of the comic's title. Defaults to empty.

=item * B<title_suffix> Optional suffix to use in the post's title. Will be
    placed after the comic's title. Defaults to empty.

=back

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new();

    croak($self->message('Must pass Reddit configuration hash')) unless (%settings);
    croak($self->message('Must pass Reddit.username')) unless ($settings{'username'});
    croak($self->message('Must pass Reddit.password')) unless ($settings{'password'});
    croak($self->message('Must pass Reddit.secret')) unless ($settings{'secret'});
    croak($self->message('Must pass Reddit.client_id')) unless ($settings{'client_id'});

    my %mandatory_settings = (
        user_agent => 'Comic::Social::Reddit by /u/beercomics',
        username => $settings{'username'},
        password => $settings{'password'},
        client_id => $settings{'client_id'},
        secret => $settings{'secret'},
    );
    my %optional_settings;
    if ($settings{'client_settings'}) {
        %optional_settings = %{$settings{'client_settings'}};
    }
    my %client_settings = (%mandatory_settings, %optional_settings);
    $self->{reddit} = Reddit::Client->new(%client_settings);

    @{$self->{settings}->{default_subreddit}} = ();
    my $def_srs = $settings{'default_subreddit'};
    push @{$self->{settings}->{'default_subreddit'}}, $self->_subreddits('Reddit.default_subreddit', $def_srs);

    $self->{title_prefix} = $settings{'title_prefix'} || '';
    $self->{title_suffix} = $settings{'title_suffix'} || '';

    return $self;
}


sub _subreddits {
    my ($self, $what, $subreddits) = @ARG;

    if ($subreddits) {
        if (ref $subreddits eq '') {
            return $subreddits;
        }
        elsif (ref $subreddits eq 'ARRAY') {
            return @{$subreddits};
        }
        else {
            croak($self->message("$what must be scalar or array"));
        }
    }
    return ();
}


=head2 post

Posts the given Comic to the configured default subreddit(s) and any
subreddits mentioned in the comic's meta data.

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

If a language has no C<subreddit> setting (in neither the global
default_subreddit settings nor the comic's settings), that comic language
won't be posted. For example, if the comic above was available in English,
German, and Spanish, but the C<reddit> settings don't mention Spanish, the
Spanish version won't be posted.

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

=back

Returns any messages from Reddit, separated by newlines.

Note that posting can take a long time, especially on new accounts, as
Reddit may allow you to only post once every ten minutes. This method will
wait and retry until it either managed to post to all requested subreddits
or until it receives an error.

=cut

sub post {
    my ($self, $comic) = @ARG;

    my @result;
    foreach my $language ($comic->languages()) {
        foreach my $subreddit ($self->_get_subreddits($comic, $language)) {
            push @result, $self->_post($comic, $language, $subreddit);
        }
    }

    return join "\n", @result;
}


sub _get_subreddits {
    my ($self, $comic, $language) = @ARG;
    my @subreddits;

    # Global default subredit
    my $use_default = $comic->{meta_data}->{reddit}->{'use-default'} // 1;
    if ($use_default) {
        push @subreddits, @{$self->{settings}->{default_subreddit}};
    }

    # Subreddits specified in the comic
    push @subreddits, $self->_subreddits_from_comic_meta_data($comic, $language);

    # Filter out empty values in case someone leaves "" in the config.
    return grep { $_ } @subreddits;
}


sub _subreddits_from_comic_meta_data {
    my ($self, $comic, $language) = @ARG;

    my @subreddits;
    my $json = $comic->{meta_data}->{reddit}->{$language}->{subreddit};
    push @subreddits, $self->_subreddits("$language Reddit meta data", $json);
    return @subreddits;
}


sub _post {
    my ($self, $comic, $language, $subreddit) = @ARG;

    my $title = "$self->{title_prefix}$comic->{meta_data}->{title}{$language}$self->{title_suffix}";
    $subreddit = _normalize_subreddit($subreddit);

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
            my $error = _wait_for_reddit_limit($comic, $EVAL_ERROR);
            if ($error) {
                return $self->message("$language: /r/$subreddit: $error");
            }
        };
    }

    return $self->message("Posted '$title' ($comic->{url}{$language}) to $subreddit ($full_name) at "
        . $self->{reddit}->get_link($full_name)->{permalink});
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
        return "Don't know what reddit complains about: '$error'";
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
