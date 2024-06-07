package Comic::Check::Tag;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use String::Util 'trim';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords html Wenner merchantability perlartistic metadata


=head1 NAME

Comic::Check::Tag  - Checks a comic's tags for consistency.


=head1 SYNOPSIS

    my $check = Comic::Check::Tag->new('tags', 'who');
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }


=head1 DESCRIPTION

This flags comics that contain tags that differ from previously seen tags in
case or white space only. This may help with case- and white space sensitive
tag clouds.

Comic::Check::Tag keeps track of the tags it has seen, so you need to
use the same instance for checking all your comics.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Tag that works on metadata in each Comic.

For example, for a tag named "tags", the metadata would be expected as:

    {
        "tags": {
            "English": ["beer", "ale", "lager"]
        }
    }

Parameters:

=over 4

=item * B<@tags> Tags to check. These tags need to be in the per-language
    comic metadata. You could use tags for the people appearing in the
    comic, or general purpose keywords associated with the comic. Passing no
    tags effectively disables this Check.

=back

=cut


sub new {
    my ($class, @tags) = @ARG;
    my $self = $class->SUPER::new();
    @{$self->{tags}} = @tags;
    return $self;
}


=head2 check

Checks the given Comic's tags.

Parameters:

=over 4

=item * B<$comic> Comic to check. Will check the tags given in the
    Comic::Check::Tag constructor for all languages the comic has.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    foreach my $tag (@{$self->{tags}}) {
        foreach my $language ($comic->languages()) {
            my $tag_values = $comic->{meta_data}->{$tag}->{$language};
            if (!defined $tag_values || @{$tag_values} == 0) {
                $self->warning($comic, "No $language $tag");
            }

            foreach my $tag_value (@{$tag_values}) {
                $self->warning($comic, "Empty $language $tag") if ($tag_value =~ m/^\s*$/);
            }

            $self->_check_against($comic, $tag, $language);
        }
    }
    return;
}


sub _check_against {
    my ($self, $comic, $tag, $language) = @ARG;

    foreach my $oldcomic (@{$self->{comics}}) {
        next if ($comic eq $oldcomic);

        foreach my $oldtag (@{$oldcomic->{meta_data}->{$tag}->{$language}}) {
            foreach my $newtag (@{$comic->{meta_data}->{$tag}->{$language}}) {
                next if $oldtag eq $newtag;

                my $location = "$tag '$newtag' and '$oldtag' from $oldcomic->{srcFile}";

                if (lc $oldtag eq lc $newtag) {
                    $self->warning($comic, "$location only differ in case");
                }

                # Uses string extrapolation to copy the variables, so that the white space
                # removal does not modify the original comic values.
                # I had no luck with Storable::dclone. :-/
                my $trimmed_old = "$oldtag";
                $trimmed_old =~ s/\s+//g;
                my $trimmed_new = "$newtag";
                $trimmed_new =~ s/\s+//g;
                if ($trimmed_old eq $trimmed_new) {
                    $self->warning($comic, "$location only differ in white space");
                }
            }
        }
    }

    return;
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
