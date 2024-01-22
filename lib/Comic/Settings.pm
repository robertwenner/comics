package Comic::Settings;

use strict;
use warnings;
use utf8;

use Readonly;
use English '-no_match_vars';
use Carp;
use JSON;
use Hash::Merge;
use Clone;

use version; our $VERSION = qv('0.0.3');


# Constants to point to the objects in the configuration where to find
# settings for pluggable modules.
Readonly our $CHECKS => 'Checks';
Readonly our $GENERATORS => 'Out';
Readonly our $UPLOADERS => 'Uploader';
Readonly our $SOCIAL_MEDIA_POSTERS => 'Social';

# Default settings and paths.
Readonly::Hash my %DEFAULT_SETTINGS => (
    'Paths' => {
        'siteComics' => 'comics/',
        'published' => 'generated/web/',
        'unpublished' => 'generated/backlog/',
    },
    'LayerNames' => {
        'TranscriptOnlyPrefix' => 'Meta',
        'NoTranscriptPrefix' => 'NoText',
        'Frames' => 'Frames',
    },
);


=encoding utf8

=for stopwords JSON Wenner perlartistic MERCHANTABILITY hashref


=head1 NAME

Comic::Settings - Compiles settings from different sources.

=head1 SYNOPSIS

    my $settings = Comic::Settings->new();
    $settings->load("path/to/my/settings.json");
    $settings->load("{...}");
    ...
    my $s = $settings->clone();
    if ($s->{'top_level_key'} == 1) {
        ...
    }


=head1 DESCRIPTION

Create one instance of this class, load any JSON configuration files through
C<from_str>, then call C<clone> to get a merged hash of defaults and loaded
settings to pass to each Comic. (Later loaded settings override earlier
loaded ones.)

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new empty Comic::Settings.

Parameters:

=over 4

=item * B<%args> initial (optional) settings to override the defaults.

=back

=cut


sub new {
    my ($class, %settings) = @ARG;
    my $self = bless{}, $class;

    $self->{parser} = JSON->new();
    $self->{parser}->relaxed(1);
    $self->{merger} = Hash::Merge->new('RIGHT_PRECEDENT');
    $self->{settings} = $self->{merger}->merge(\%DEFAULT_SETTINGS, \%settings);

    return $self;
}


=head2 load_str

Load settings from the given string. Any previously set values with the same
key are overwritten with the new values. Validates and normalizes the new
global settings (e.g., makes sure all paths have trailing slashes).

Parameters:

=over 4

=item * B<$json> JSON string to load. It must contain a top level object.
    Other checks are relaxed, i.e., comments from a hash mark to the end of
    the line are allowed, as are trailing commas (e.g., after the last list
    item).

=back

=cut

sub load_str {
    my ($self, $json) = @ARG;

    my $new = $self->{parser}->decode($json);

    if (ref $new ne ref {}) {
        # The JSON parser is configured to validate relaxed to allow e.g.,
        # trailing commas for user friendliness. However, that also means
        # it will accept a top level array. That changes the return value
        # in get() from hash to array, and when an JSON array gets merged
        # with a hash, we lose elements. Hence reject top level arrays in
        # the JSON data. Frankly, there wouldn't be any context anyway for
        # users of this class to figure out what the array refers to anyway.
        croak('Must have an object; top level arrays are not supported');
    }

    # Validate

    # Paths, if given
    if (exists $new->{Paths}) {
        # is a hash
        if (ref $new->{Paths} ne ref {}) {
            croak('Paths must be a hash / object');
        }
        # is not empty; possibly a typo or attempt to clean the defaults?
        unless (%{$new->{Paths}}) {
            croak('Paths cannot be empty');
        }
        # hash elements are scalars
        foreach my $path (keys %{$new->{Paths}}) {
            croak("Paths.$path must be a single value") unless (ref ${$new->{Paths}}{$path} eq '');
        }
    }

    # Merge
    $self->{settings} = $self->{merger}->merge($self->{settings}, $new);

    # Normalize

    # Make sure all paths have a trailing slash, for easy concatenation.
    foreach my $path (keys %{$self->{settings}{Paths}}) {
        ${$self->{settings}{Paths}}{$path} .= q{/} unless (${$self->{settings}->{Paths}}{$path} =~ m{/$}x);
    }

    return;
}


=head2 clone

Clones this Settings, returning a hashref of actual settings.

=cut

sub clone {
    my ($self) = @ARG;

    return Clone::clone($self->{settings});
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

None.


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
