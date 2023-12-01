package Comic::Out::Series;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Generator;
use base('Comic::Out::Generator');
use Comic::Out::Template;


=encoding utf8

=for stopwords Wenner merchantability perlartistic outdir html prev


=head1 NAME

Comic::Out::Series - Generate per-series hyperlinks between html comics.


=head1 SYNOPSIS

    my $feed = Comic::Out::Series->new(%settings);
    $feed->generate($comic);
    $feed->generate_all(@comics);


=head1 DESCRIPTION

Collects series from all comics' metadata and links comics to other comics
in that series.

A series is an ordered (by date) list of comics, where the story arch
progresses from earlier to later comics. This is different from tags, where
order of the comics does not matter; all comics with a tag are somehow related.

Each comic can belong to only one series.

Series are case-sensitive, i.e., a comic in the "Beer" series will not refer to one
in the "beer" series.

Comics that are not (yet) published on the web are ignored.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Series.

Parameters are taken from the C<Out.Series> configuration:

=over 4

=item * B<$settings> Settings hash.

=back

The passed settings can have:

=over 4

=item * B<$series> name of the metadata element to collect. Defaults to "series".

The C<series> needs to appear in the comic metadata as an object of language
to series title:

    'meta_data' => {
        'series': {
            'English' => 'brewing beer',
        },
    }

=back

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->optional('collect', 'scalar', 'series');
    $self->flag_extra_settings();

    %{$self->{series}} = ();

    return $self;
}


=head2 generate

Collects the series tag from the given Comic.

Parameters:

=over 4

=item * B<$comic> Comic to process.

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    return if ($comic->not_yet_published());

    my $me = ref $self;

    my $collect = $self->{settings}->{collect};
    my $series_for_all_languages = $comic->{meta_data}->{$collect};
    return unless (defined $series_for_all_languages);

    if (ref $series_for_all_languages ne ref {}) {
        $comic->warning("$me: $collect metadata must be a map of language to title");
        return;
    }

    foreach my $language ($comic->languages()) {
        # Ignore a comic that doesn't have series in the metadata; not all comics belong
        # to a series.
        my $series = $series_for_all_languages->{$language};
        next unless (defined $series);

        if (ref $series ne '') {
            $comic->warning("$me: $language $collect metadata per language must be a single value");
            next;
        }

        push @{$self->{series}->{$language}->{$series}}, $comic->{href}->{$language};
    }

    return;
}


=head2 generate_all

Writes the collected series links to each of the passed comics in the same series.

Generates a web page for each series using the passed template.

Parameters:

=over 4

=item * B<@comics> Comics to process.

=back

Defines these variables in each passed Comic:

=over 4

=item * B<%series> hash of the keys first, prev, next, and last to the first,
    previous, next, and last comic in the series. The first comic won't have
    prev and first; and the last won't have next and last.
    This is always called C<series>, independent of the C<collect> configuration.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my $me = ref $self;
    my $seen = 0;
    foreach my $language (keys %{$self->{series}}) {
        $seen += keys %{$self->{series}->{$language}};
    }
    croak("$me: no comics had the '$self->{settings}->{collect} metadata; typo?") unless ($seen);

    my $collect = $self->{settings}->{collect};
    foreach my $comic (@comics) {
        my $series_for_all_languages = $comic->{meta_data}->{$collect};

        foreach my $language ($comic->languages()) {
            # Define an empty hash for easy use in templates.
            $comic->{series}->{$language} = {};
            next unless (defined $series_for_all_languages);

            my $series = $comic->{meta_data}->{$collect}->{$language};
            next unless ($series);
            next unless ($self->{series}->{$language}->{$series});

            my @series = @{$self->{series}->{$language}->{$series}};
            my ($pos) = grep { $series[$_] eq $comic->{href}->{$language} } 0 .. $#series;
            if (!defined $pos) {
                # Comic not found in the list of its series: This happens when the
                # current comic is not yet published, but others in the series are.
                # Add series links as good as we can, for a realistc preview in the
                # backlog.
                # First link is clear (first in series. Assume the current last will
                # be the previous for this comic. If there are multiple unpublished
                # comics in the series, they are all considered the last ones.
                $comic->{series}->{$language}->{'first'} = $series[0];
                $comic->{series}->{$language}->{'prev'} = $series[-1];
            }
            else {
                if ($pos > 0) {
                    $comic->{series}->{$language}->{'first'} = $series[0];
                    $comic->{series}->{$language}->{'prev'} = $series[$pos - 1];
                }
                if ($pos < $#series) {
                    $comic->{series}->{$language}->{'next'} = $series[$pos + 1];
                    $comic->{series}->{$language}->{'last'} = $series[-1];
                }
            }
        }
    }

    return;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

Comic metadata, the Comic modules.


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
