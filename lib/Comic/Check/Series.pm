package Comic::Check::Series;

use strict;
use warnings;
use English '-no_match_vars';
use String::Util 'trim';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=head1 NAME

Comic::Check::Series - Checks a comic's series meta information.

=head1 SYNOPSIS

    my $check = Comic::Check::Series->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }
    # ...
    $check->final_check();

=head1 DESCRIPTION

Comic::Check::Series keeps track of the comics it has seen and hence all
comics need to be checked by the same Comic::Check::Series.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Series.

=cut


sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 check

Checks the given comic's series meta information to catch copy and paste
errors or when a comic belongs to a series in one language but not in
another (which seems odd).

Parameters:

=over 4

=item * Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->languages()) {
        my $need = _series_for($comic, $language);
        next if (!defined $need);
        if ($need eq '') {
            $comic->_warn("Empty series for $language");
            next;
        }

        foreach my $l ($comic->languages()) {
            next if ($language eq $l);
            my $has = _series_for($comic, $l);
            if (!$has) {
                $comic->_warn("No series tag for $l but for $language");
            }
            elsif ($need eq $has) {
                $comic->_warn("Duplicated series tag '$need' for $l and $language");
                # Do not exit the loop early here to avoid a duplicated warning
                # when the check complains about the duplicated series for both
                # languages. Exiting would skip other checks for other languages,
                # like checking if there is a series tag at all above.
            }
        }
    }
    return;
}


sub _series_for {
    my ($comic, $language) = @ARG;

    return unless ($comic->{meta_data}->{series});
    return trim($comic->{meta_data}->{series}{$language});
}


=head2 final_check

Does a final pass through all comics seen and cross-checks them. This
detects possible typos in series names when there is only one comic in a
series.

This method must be called when all comics have been processed, or it will
lead to false positives when it sees the first (and so far only) comic in a
series, even if other comics later belong to the same series.

=cut

sub final_check {
    my ($self) = @ARG;

    my %series_count;

    foreach my $comic (@{$self->{comics}}) {
        foreach my $language (keys %{$comic->{meta_data}->{series}}) {
            my $series = _series_for($comic, $language);
            $series_count{$language}{$series}++;
        }
    }

    foreach my $comic (@{$self->{comics}}) {
        foreach my $language (keys %{$comic->{meta_data}->{series}}) {
            foreach my $series ($comic->{meta_data}->{series}->{$language}) {
                if ($series_count{$language}{$series} == 1) {
                    $comic->_note("$language has only one comic in the '$series' series");
                }
            }
        }
    }

    return;
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
