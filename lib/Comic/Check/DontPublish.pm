package Comic::Check::DontPublish;

use strict;
use warnings;
use English '-no_match_vars';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=head1 NAME

Comic::Check::DontPublish - Checks a comic for a special marker.

=head1 SYNOPSIS

    my $check = Comic::Check::DontPublish->new('DONTT_PUBLISH');
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }

=head1 DESCRIPTION

If the special marker is found in any text in the comic, the comic is
flagged with a warning if it's not due for publishing yet, and an error if
it is.

The idea is that you can leave yourself reminders in the comic for things
you want to get back to before it's published. The idea comes from software
development, where you may want to revisit areas of the code before committing
to source control; see <L:Don't commit: Avoiding distractions while coding|
https://www.sparkpost.com/blog/dont-commit-avoiding-distractions-while-coding/>.

Comic::Check::DontPublish can be used for multiple comics.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::DontPublish.

Parameters:

=over 4

=item * Don't publish marker(s). If any of these texts is found, the comic
    is flagged. Pick something that doesn't appear normally in your comics,
    e.g., "DONT_PUBLISH". The check is case-sensitive (and an all-caps term
    may be easier for humans to spot).

=back

=cut


sub new {
    my ($class, @markers) = @ARG;
    my $self = $class->SUPER::new();
    @{$self->{markers}} = @markers;
    return $self;
}


=head2 check

Checks the given Comic for the don't publish marker(s) passed in the
Comic::Check::DontPublish constructor.

Parameters:

=over 4

=item * Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    foreach my $marker (@{$self->{markers}}) {
        $self->_check_json($comic, '', $comic->{meta_data}, $marker);
        $self->_check_texts($comic, $marker);
    }

    return;
}


sub _check_json {
    my ($self, $comic, $where, $what, $marker) = @ARG;

    if (ref($what) eq 'HASH') {
        foreach my $key (keys %{$what}) {
            $self->_check_json($comic, "$where > $key", $what->{$key}, $marker);
        }
    }
    elsif (ref($what) eq 'ARRAY') {
        for my $i (0 .. $#{$what}) {
            $self->_check_json($comic, $where . '[' . ($i + 1) . ']', $what->[$i], $marker);
        }
    }
    elsif ($what =~ m/$marker/m) {
        $comic->_warn("In JSON$where: $what");
    }

    return;
}


sub _check_texts {
    my ($self, $comic, $marker) = @ARG;

    foreach my $layer ($comic->get_all_layers()) {
        my $text = $layer->textContent();
        if ($text =~ m/($marker\s*[^\r\n]*)/m) {
            my $label = $layer->{'inkscape:label'};
            $comic->_warn("In $label layer: $1");
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

Tied to Inkscape's way of creating / marking layers, i.e., relies on the
"inkscape:label" attribute on the layer to indicate where it found a marker.


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
