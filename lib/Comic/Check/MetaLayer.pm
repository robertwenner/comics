package Comic::Check::MetaLayer;

use strict;
use warnings;
use English '-no_match_vars';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=for stopwords Wenner merchantability perlartistic Inkscape

=encoding utf8

=head1 NAME

Comic::Check::MetaLayer - Checks the meta layer's texts.

=head1 SYNOPSIS

    my $check = Comic::Check::MetaLayer->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }

=head1 DESCRIPTION

Comic::Check::MetaLayer doesn't keeps track of comics. It's safe to be shared
but doesn't need to be shared.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::MetaLayer.

Parameters:

=over 4

=item * B<$prefix> Meta prefix; defaults to C<Meta>. Meta layers are found
    by looking for this meta prefix followed by the language. For example,
    if meta marker is C<Meta> and language is C<English>, the comic is
    expected to have an Inkscape layer called C<MetaEnglish>.

=back

=cut


sub new {
    my ($class, $prefix) = @ARG;
    my $self = $class->SUPER::new();
    $self->{prefix} = $prefix || 'Meta';
    return $self;
}


=head2 check

Checks the text in the given Comic's Inkscape meta layers.

Parameters:

=over 4

=item * B<$comic> Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->languages()) {
        unless ($comic->has_layer("$self->{prefix}$language")) {
            $self->warning($comic, "No $self->{prefix}$language layer");
            next;
        }

        my $first_text = ($comic->texts_in_language($language))[0];
        my $any_text_found = 0;
        my $first_text_is_meta = 0;
        foreach my $text ($comic->texts_in_layer("$self->{prefix}$language")) {
            $any_text_found = 1;
            if ($first_text eq $text) {
                $first_text_is_meta = 1;
            }
        }
        if (!$any_text_found) {
            $self->warning($comic, "No texts in $self->{prefix}$language layer");
        }
        elsif (!$first_text_is_meta) {
            $self->warning($comic, "First text must be from $self->{prefix}$language, " .
                "but is '$first_text' from layer $language");
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
