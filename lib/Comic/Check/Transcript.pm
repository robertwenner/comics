package Comic::Check::Transcript;

use strict;
use warnings;
use English '-no_match_vars';
use String::Util 'trim';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=head1 NAME

Comic::Check::Transcript - Checks a comic's transcript for meta information
and real comic text order.

=head1 SYNOPSIS

    my $check = Comic::Check::Transcript->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }

=head1 DESCRIPTION

Comic::Check::Transcript doesn't keeps track of comics. It's safe to be shared
but doesn't need to be shared.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Transcript.

=cut


sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 check

Checks that the given Comic's transcript always has a speaker indicator
before regular text. This helps to generate a transcript where the meta
layer has an indicator of what's happening and who says something, and the
real language layer has the text that the actors actually say. A speaker
indicator is a text that ends with a colon.

Texts are ordered for comparison per frames row from top to bottom and from
left to right.

Parameters:

=over 4

=item * Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->languages()) {
        my $trace = '';
        my $previous = '';
        foreach my $t ($comic->_texts_for($language)) {
            $trace .= "[$t]";
            if (_both_names($previous, $t)) {
                $comic->_croak("transcript mixed up in $language: $trace");
            }
            $previous = $t;
        }

        # Check that the comic does not end with a speaker indicator.
        if (trim($previous) =~ m{:$}) {
            $comic->_croak("speaker's text missing after '$previous', trace is $trace");
        }
    }

    return;
}


sub _both_names {
    my ($a, $b) = @_;

    if ($a =~ m/:$/ && $b =~ m/:$/) {
        return 1;
    }

    $a =~ s/:$//;
    $b =~ s/:$//;
    if (lc $a eq lc $b && $a ne '') {
        return 1;
    }
    return 0;
}


=for stopwords html Wenner merchantability perlartistic


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
