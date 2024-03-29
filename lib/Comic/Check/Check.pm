package Comic::Check::Check;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use Comic::Modules;

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords html Wenner merchantability perlartistic


=head1 NAME

Comic::Check::Check  - base class for all comic checks.


=head1 SYNOPSIS

Should not be used directly.


=head1 DESCRIPTION

All Comic::Checks should derive from this class.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Check.

=cut


sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    @{$self->{comics}} = ();
    return $self;
}


=head2 notify

Notifies this Check of the given comic. This does not mean to check the
given comic, but keep it in mind for checks that compare comics to
previously seen ones.

The base class implementation just remembers the passed comic in its
C<comics> array. Derived classes can access that comic array in e.g.,
C<final_check>.

Parameters:

=over 4

=item * B<$comic> Comic to remember.

=back

=cut

sub notify {
    my ($self, $comic) = @ARG;

    push @{$self->{comics}}, $comic;
    return;
}


=head2 check

Checks the given Comic.

The base class implementation croaks. Derived classes need to implement this
method and do whatever per-comic checks they need to do.

Parameters:

=over 4

=item * B<comic> Comic to check.

=back

=cut

sub check {
    my ($self) = @ARG;
    confess('Comic::Check::Check::check must be overridden in ' . ref $self);
}


=head2 final_check

Checks all previously collected comics after all comics have been checked.

The base class implementation does nothing. Derived classes can override this
method to do checks once all comics have been seen, e.g., to check that a
series name is not unique (may be a typo).

=cut

sub final_check {
    # Ignore.
    return;
}


=head2 find_all

Finds all Check modules.

=cut

sub find_all {
    return Comic::Modules::find_modules(qr{/(Comic/Check/[^.]+[.]pm)$}, 'Comic/Check/Check.pm');
}


=head2 warning

Puts a warning on the given comic.

Parameters:

=over 4

=item * B<self> Check instance.

=item * B<comic> Comic to add the warning to.

=item * B<message> Warning message text.

=back

=cut

sub warning {
    my ($self, $comic, $message) = @ARG;
    $comic->warning(ref($self) . ': ' . $message);
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
