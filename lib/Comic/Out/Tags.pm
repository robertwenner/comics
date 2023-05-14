package Comic::Out::Tags;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Generator;
use base('Comic::Out::Generator');


=encoding utf8

=for stopwords Wenner merchantability perlartistic


=head1 NAME

Comic::Out::Tags - Collects tags from comics to provide tagging in comic pages.


=head1 SYNOPSIS

    my $feed = Comic::Out::Tags->new(%settings);
    $feed->generate($comic);
    $feed->generate_all(@comics);


=head1 DESCRIPTION

Collects tags from all comics and allows comics to link to other comics that
share the same tags.

Tags are case-sensitive, i.e., a comic tagged "Beer" will not refer to one
tagged "beer".

These kinds of comics are ignored for tag processing:

=over 4

=item B<*> Untitled comics (they are not considered to have any languages).

=item B<*> Comics that are not yet published.

=item B<*> Comics that are not published on the web.

=back

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Tags.

Parameters are taken from the C<Out.Tags> configuration:

=over 4

=item * B<$settings> Settings hash.

=back

The passed settings can have:

=over 4

=item * B<collect> array of metadata tag names to collect. In the comics,
these must be found as hashes of languages to arrays of the actual tags, as
top-level attributes in the comic's metadata.

Example comic metadata:

    'meta_data' => {
        tags: {
            'English' => ['some value', 'other value'],
        },
    },

Passing "tags" for the "collect" parameter will pick the example values above.

=back

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->optional('collect', 'array-or-scalar', ['tags']);
    $self->flag_extra_settings();
    %{$self->{tags}} = ();

    return $self;
}


=head2 generate

Collects the tags from the given Comic.

Parameters:

=over 4

=item * B<$comic> Comic to process.

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    return if ($comic->not_yet_published());
    foreach my $language ($comic->languages()) {
        foreach my $tag (@{$self->{settings}{collect}}) {
            next unless $comic->{meta_data}{$tag};
            if (ref $comic->{meta_data}{$tag} ne 'HASH') {
                $comic->keel_over("$tag meta data must be a hash of languages to arrays of values");
            }
            next if (keys %{$comic->{meta_data}{$tag}} == 0);
            if (ref $comic->{meta_data}{$tag}{$language} ne 'ARRAY') {
                $comic->keel_over("$tag $language must be an array");
            }
            foreach my $collect (@{$comic->{meta_data}{$tag}{$language}}) {
                $self->{tags}{$language}{$collect}{$comic->{meta_data}{title}{$language}} = $comic->{href}{$language};
            }
        }
    }

    return;
}


=head2 generate_all

Writes the collected tags to each of the passed comics.

Parameters:

=over 4

=item * B<@comics> Comics to process.

=back

Defines these variables in the passed Comic:

=over 4

=item * B<%tags> A hash of languages to hashes of comic titles to relative
    comic URLs (C<href>). The comic having these tags can turn those into links
    to the other comics that use the same tags.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    foreach my $comic (@comics) {
        # Unpublished comics could link to others, but then the code here
        # would need to know about backlog vs published paths. A comic that's
        # not (yet) published on the web must never be included in a published
        # comic's tags.
        next if ($comic->not_yet_published());
        foreach my $language ($comic->languages()) {
            $comic->{tags}{$language} = {};
            foreach my $tag (@{$self->{settings}{collect}}) {
                foreach my $collect (@{$comic->{meta_data}{$tag}{$language}}) {
                    foreach my $title (keys %{$self->{tags}{$language}{$collect}}) {
                        if ($comic->{meta_data}->{title}{$language} ne $title) {
                            $comic->{tags}{$language}{$collect}{$title} = $self->{tags}{$language}{$collect}{$title};
                        }
                    }
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
