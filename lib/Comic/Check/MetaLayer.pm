package Comic::Check::MetaLayer;

use strict;
use warnings;
use English '-no_match_vars';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=head1 NAME

Comic::Check::MetaLayer - Checks the m,eta layer's texts.

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

=cut


sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 check

Checks the text in the given Comic's Inkscape meta layers.

MetaLayer expectes meta layers be named as Meta + language, e.g.,
MetaEnglish or MetaDeutsch.

Parameters:

=over 4

=item * Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->_languages()) {
        $comic->_get_transcript($language);

        unless ($comic->{xpath}->findnodes($comic->_find_layers("Meta$language"))) {
            $comic->_warn("No Meta$language layer");
            return;
        }

        my $first_text = ($comic->_texts_for($language))[0];
        my $text_found = 0;
        my $first_text_is_meta = 0;
        foreach my $text ($comic->{xpath}->findnodes(Comic::_text("Meta$language"))) {
            $text_found = 1;
            if ($first_text eq Comic::_text_content($text)) {
                $first_text_is_meta = 1;
            }
        }
        if ($text_found) {
            $comic->_warn("First text must be from Meta$language, but is $first_text")
                unless ($first_text_is_meta);  # would be nice to show the layer here, too
        }
        else {
            $comic->_warn("No texts in Meta$language layer");
        }
    }
    return;
}


=for stopwords html Wenner merchantability perlartistic Inkscape


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

Copyright (c) 2015 - 2020, Robert Wenner C<< <rwenner@cpan.org> >>.
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
