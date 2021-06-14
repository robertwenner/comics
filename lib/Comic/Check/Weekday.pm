package Comic::Check::Weekday;

use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use String::Util 'trim';
use DateTime;
use DateTime::Format::ISO8601;

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=head1 NAME

Comic::Check::Weekday - Checks a comic's published date is always on certain
weekdays.

=head1 SYNOPSIS

    my $check = Comic::Check::Weekday->new(5);
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }

=head1 DESCRIPTION

For regularly published comics, it may make sense to check that a comic is
scheduled for a certain weekday, e.g., every Friday.

Comic::Check::Weekday does not keeps track of comics. It's safe to be shared
but doesn't need to be shared.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Weekday.

Parameters:

=over 4

=item * B<weekday> Weekday when comics are published. Pass 1 for Monday, 2
    for Tuesday, and so on. If no weekday is given, this check is
    effectively disabled.

=back


=cut


sub new {
    my ($class, $weekday) = @ARG;
    my $self = $class->SUPER::new();

    if (defined $weekday) {
        ## no critic(ValuesAndExpressions::ProhibitMagicNumbers)
        croak("Bad weekday $weekday, use 1 (Mon) - 7 (Sun)") if ($weekday < 1 || $weekday > 7);
        ## use critic
    }

    $self->{weekday} = $weekday;
    return $self;
}


=head2 check

Checks that the given Comic's published date is the weekday passed in the
constructor.

Parameters:

=over 4

=item * B<$comic> Comic to check. Comics without a published date are
    silently ignored.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    return unless ($self->{weekday});

    my $published_when = trim($comic->{meta_data}->{published}->{when});
    return unless($published_when);
    my $published_date = DateTime::Format::ISO8601->parse_datetime($published_when);

    if ($published_date->day_of_week() != $self->{weekday}) {
        $comic->_warn('scheduled for ' . $published_date->day_name());
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
