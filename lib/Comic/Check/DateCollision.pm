package Comic::Check::DateCollision;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use String::Util 'trim';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8


=head1 NAME

Comic::Check::DateCollision - Checks that comics are not published on the
same day in the same location.


=head1 SYNOPSIS

    my $check = Comic::Check::DateCollision->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }


=head1 DESCRIPTION

For regularly published comics you may want to avoid publishing multiple
comics on the same date. However, it's probably fine to publish a comic in
different locations on the same day.

Comic::Check::DateCollision does keeps track of all comics to detect whether
comics are published on the same date. Hence you need to use one
Comic::Check::DateCollision for all your comics.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::DateCollision.

=cut


sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 check

Checks the given Comic's publishing date for collisions with other comics in
the same publishing location.

Parameters:

=over 4

=item * B<$comic> Comic to check. Comics without a published date are ignored.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    my $published_when = trim($comic->{meta_data}->{published}->{when});
    return unless($published_when);

    my $published_where = trim($comic->{meta_data}->{published}->{where});

    foreach my $c (@{$self->{comics}}) {
        next if ($c == $comic);
        my $pub_when = trim($c->{meta_data}->{published}->{when});
        my $pub_where = trim($c->{meta_data}->{published}->{where});

        next unless($pub_when);
        foreach my $l ($comic->languages()) {
            next if ($comic->not_for($l) != $c->not_for($l));
            if ($published_when eq $pub_when && $published_where eq $pub_where) {
                $self->warning($comic, "Duplicated date with $c->{srcFile}");
            }
        }
    }

    my $created = trim($comic->{meta_data}->{date});
    if (!$created) {
        $self->warning($comic, 'No creation date');
    }
    elsif ($created !~ m{^\d{4}-\d{2}-\d{2}$}) {
        $self->warning($comic, 'Creation date must be in yyyy-mm-dd format');
    }
    elsif ($created gt $published_when) {
        $self->warning($comic, "Published date ($published_when) is before creation date ($created)");
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
