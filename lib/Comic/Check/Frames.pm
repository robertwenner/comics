package Comic::Check::Frames;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Readonly;
use Comic::Consts;

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords html Wenner merchantability perlartistic


=head1 NAME

Comic::Check::Frames - Checks a comic's frame style, width, and positions.


=head1 SYNOPSIS

    my $check = Comic::Check::Frames->new(
        'FRAME_ROW_HEIGHT' => 10,
    );
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }


=head1 DESCRIPTION

Comic::Check::Frames warns if frames (i.e., borders around the images) are
inconsistent within a comic: too little or too much space between frames,
frames not aligned with each other, some frames thicker than others.

If you use a template for your comics that already has the frames, this
check probably won't find anything. But while you work on that template,
this check could be helpful.

Comic::Check::Frames does not keep internal state; you can use one instance
for all comics.

=cut

# Default allowed deviation from expected frame width in pixels.
Readonly my $FRAME_WIDTH_DEVIATION => 0.25;


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Frames.

Parameters:

Hash of values; any value not given will default to the constant by the same
name in C<Comic::Const>.

=over 4

=item * B<FRAME_ROW_HEIGHT>: After how many pixels difference to the previous
    frame a frame is assumed to be on the next row.

=item * B<FRAME_SPACING>: How many pixel space there should be between frames.
    The same number is used for both vertical and horizontal space.

=item * B<FRAME_SPACING_TOLERANCE>: Maximum additional tolerance when looking
    whether frames are spaced as expected.

=item * B<FRAME_TOLERANCE>: Tolerance in pixels when looking for frames.

=item * B<FRAME_WIDTH>: Expected frame thickness in pixels.

=item * B<FRAME_WIDTH_DEVIATION>: Allowed deviation from expected frame width in
    pixels. This is used to avoid finicky complaints about frame width that
    are technically different but look the same for human eyes.

=back

=cut


sub new {
    my ($class, %args) = @ARG;
    my $self = $class->SUPER::new();

    my %default_args = (
        'FRAME_ROW_HEIGHT' => $Comic::Consts::FRAME_ROW_HEIGHT,
        'FRAME_SPACING' => $Comic::Consts::FRAME_SPACING,
        'FRAME_SPACING_TOLERANCE' => $Comic::Consts::FRAME_SPACING_TOLERANCE,
        'FRAME_TOLERANCE' => $Comic::Consts::FRAME_TOLERANCE,
        'FRAME_WIDTH' => $Comic::Consts::FRAME_WIDTH,
        'FRAME_WIDTH_DEVIATION' => $Comic::Consts::FRAME_WIDTH_DEVIATION,
        %args,
    );
    foreach my $arg (keys %default_args) {
        $self->{$arg} = $default_args{$arg};
    }

    return $self;
}


=head2 check

Checks the given comic's frames.

Parameters:

=over 4

=item * B<$comic> Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    # frame coordinate is top left corner of a rectangle
    # higher y means lower on the page, higher x means further to the right
    my $prev_top;
    my $prev_bottom;
    my $prev_right;

    my $left_most;
    my $right_most;

    my $first_row = 1;

    my @frames = $comic->all_frames_sorted();
    foreach my $f (@frames) {
        $self->_check_frame_style($comic, $f);

        my ($top, $bottom, $left_side, $right_side) = _frame_sides($f);
        $left_most = $left_side unless (defined $left_most);

        my $next_row = defined($prev_bottom) && _more_off($prev_bottom, $bottom, $self->{FRAME_ROW_HEIGHT});
        $first_row = 0 if ($next_row);
        $right_most = $right_side if ($first_row);

        if (defined $prev_bottom) {
            if ($next_row) {
                $self->_check_new_row_against_previous_row($comic, $prev_bottom, $top);
                $self->_check_row_side_alignment($comic, $left_most, $left_side, $prev_right, $right_most);
            }
            else {
                $self->_check_frame_top_bottom_alignment_in_row($comic, $prev_bottom, $bottom, $prev_top, $top);
                $self->_check_no_frame_overlap_in_row($comic, $prev_right, $left_side);
            }
        }

        $prev_bottom = $bottom;
        $prev_top = $top;
        $prev_right = $right_side;
    }

    if (@frames) {
        # Check last row's right alignment
        if (_more_off($prev_right, $right_most, $self->{FRAME_TOLERANCE})) {
            $self->warning($comic, "Frame right side not aligned: $prev_right and $right_most");
        }
    }
    return;
}


sub _check_frame_style {
    my ($self, $comic, $f) = @ARG;

    my $style = $f->getAttribute('style');
    if ($style =~ m{;stroke-width:([^;]+);}) {
        my $width = $1;
        if ($width < $self->{FRAME_WIDTH} - $self->{FRAME_WIDTH_DEVIATION}) {
            $self->warning($comic, "Frame too narrow ($width)");
        }
        if ($width > $self->{FRAME_WIDTH} + $self->{FRAME_WIDTH_DEVIATION}) {
            $self->warning($comic, "Frame too wide ($width)");
        }
    }
    else {
        $self->warning($comic, "Cannot find width in '$style'");
    }
    return;
}


sub _frame_sides {
    my ($frame) = @ARG;

    my $top = $frame->getAttribute('y') * 1.0;
    my $bottom = $top + $frame->getAttribute('height') * 1.0;
    my $left_side = $frame->getAttribute('x') * 1.0;
    my $right_side = $left_side + $frame->getAttribute('width') * 1.0;

    return ($top, $bottom, $left_side, $right_side);
}


sub _check_new_row_against_previous_row {
    my ($self, $comic, $prev_bottom, $top) = @ARG;

    if ($prev_bottom > $top) {
        $self->warning($comic, "Frames overlap y at $prev_bottom and $top");
    }
    if ($prev_bottom + $self->{FRAME_SPACING} > $top) {
        $self->warning($comic, 'Frames too close y (' . ($prev_bottom - $self->{FRAME_SPACING} - $top) . ") at $prev_bottom and $top");
    }
    if ($prev_bottom + $self->{FRAME_SPACING} + $self->{FRAME_SPACING_TOLERANCE} < $top) {
        $self->warning($comic, "Frames too far y at $prev_bottom and $top");
    }
    return;
}


sub _check_row_side_alignment {
    my ($self, $comic, $left_most, $left_side, $prev_right, $right_most) = @ARG;

    if (_more_off($left_most, $left_side, $self->{FRAME_TOLERANCE})) {
        $self->warning($comic, "Frame left side not aligned: $left_most and $left_side");
    }
    if (_more_off($prev_right, $right_most, $self->{FRAME_TOLERANCE})) {
        # Compares $prev_right because we want to only make sure the right-most frame
        # in a row of frames is aligned, not e.g., the middle one in a row with three
        # frames.
        $self->warning($comic, "Frame right side not aligned: $prev_right and $right_most");
    }
    return;
}


sub _check_frame_top_bottom_alignment_in_row {
    my ($self, $comic, $prev_bottom, $bottom, $prev_top, $top) = @ARG;

    if (_more_off($prev_bottom, $bottom, $self->{FRAME_TOLERANCE})) {
        $self->warning($comic, "Frame bottoms not aligned: $prev_bottom and $bottom");
    }
    if (_more_off($prev_top, $top, $self->{FRAME_TOLERANCE})) {
        $self->warning($comic, "Frame tops not aligned: $prev_top and $top");
    }
    return;
}


sub _check_no_frame_overlap_in_row {
    my ($self, $comic, $prev_right, $left_side) = @ARG;

    if ($prev_right > $left_side) {
        $self->warning($comic, "Frames overlap x at $prev_right and $left_side");
    }
    if ($prev_right + $self->{FRAME_SPACING} > $left_side) {
        $self->warning($comic, "Frames too close x at $prev_right and $left_side");
    }
    if ($prev_right + $self->{FRAME_SPACING} + $self->{FRAME_SPACING_TOLERANCE} < $left_side) {
        $self->warning($comic, 'Frames too far x (' . ($left_side - ($prev_right + $self->{FRAME_SPACING} + $self->{FRAME_SPACING_TOLERANCE})) . ") at $prev_right and $left_side");
    }
    return;
}


sub _more_off {
    my ($a, $b, $dist) = @ARG;
    return abs($a - $b) > $dist;
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
