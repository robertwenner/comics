package Comic::Settings;

use strict;
use warnings;

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
Readonly our $SOCIAL_MEDIA_POSTERS => 'Social';


=for stopwords JSON Wenner perlartistic MERCHANTABILITY

=head1 NAME

Comic::Settings - Compiles settings from different sources.

=head1 SYNOPSIS

    my $settings = Comic::Settings->new();
    $settings->load("path/to/my/settings.json");
    $settings->load("{...}");
    ...
    my $s = $settings->get();
    if ($s{'top_level_key'} == 1) {
        ...
    }

=head1 DESCRIPTION

Compiles configuration settings. Configuration is read as JSON data. It can
come from multiple sources, where later read settings override previously
seen ones. This allows configuration files to override each other.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new empty Comic::Settings.

=cut


sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    $self->{parser} = JSON->new();
    $self->{parser}->relaxed(1);
    $self->{merger} = Hash::Merge->new('RIGHT_PRECEDENT');
    $self->{settings} = {};
    return $self;
}


=head2 load_str

Load settings from the given string. Any previously set values with the same
key are overwritten with the new values.

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
    $self->{settings} = $self->{merger}->merge($self->{settings}, $new);

    return;
}


=head2 get

Gets all previously loaded settings in a hash reference. Any changes made to
that hash reference reflect to this Settings. Use the C<clone> method to
create a copy for modification.

=cut

sub get {
    my ($self) = @ARG;

    return $self->{settings};
}


=head2 clone

Clones this Settings. The clone can be modified without changing the
original.

=cut

sub clone {
    my ($self) = @ARG;

    my $cloned = Comic::Settings->new();
    $cloned->{settings} = Clone::clone($self->{settings});
    $cloned->{parser} = $self->{parser};
    $cloned->{merger} = $self->{merger};
    return $cloned;
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

Copyright (c) 2020 - 2011, Robert Wenner C<< <rwenner@cpan.org> >>.
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
