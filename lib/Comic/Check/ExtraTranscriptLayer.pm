package Comic::Check::ExtraTranscriptLayer;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords Wenner merchantability perlartistic Inkscape


=head1 NAME

Comic::Check::ExtraTranscriptLayer - Checks the extra transcript layer's texts.

The extra transcript layers hold texts per language that are parts of the
transcript, but usually do not appear in the actual comic.


=head1 SYNOPSIS

    my $check = Comic::Check::ExtraTranscriptLayer->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }


=head1 DESCRIPTION

Comic::Check::ExtraTranscriptLayer doesn't keeps track of comics. It's safe
to be shared but doesn't need to be shared.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::ExtraTranscriptLayer. The prefix for layer names is taken
from the C<TranscriptOnlyPrefix> in the global C<LayerNames> configuration.

=cut

sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 check

Checks the text in the given Comic's extra transcript layers.

Parameters:

=over 4

=item * B<$comic> Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    my $prefix = $comic->{settings}->{'LayerNames'}->{'TranscriptOnlyPrefix'};
    croak('No LayerNames.TranscriptOnlyPrefix configured') unless (defined $prefix);
    croak('LayerNames.TranscriptOnlyPrefix cannot be empty') unless ($prefix);

    foreach my $language ($comic->languages()) {
        unless ($comic->has_layer("$prefix$language")) {
            $self->warning($comic, "No $prefix$language layer");
            next;
        }

        my $first_text = ($comic->texts_in_language($language))[0];
        my $any_text_found = 0;
        my $first_text_is_meta = 0;
        foreach my $text ($comic->texts_in_layer("$prefix$language")) {
            $any_text_found = 1;
            if ($first_text eq $text) {
                $first_text_is_meta = 1;
            }
        }
        if (!$any_text_found) {
            $self->warning($comic, "No texts in $prefix$language layer");
        }
        elsif (!$first_text_is_meta) {
            $self->warning($comic, "First text must be from $prefix$language, " .
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
