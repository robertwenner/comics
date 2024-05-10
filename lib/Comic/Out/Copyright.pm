package Comic::Out::Copyright;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use Readonly;
use XML::LibXML;

use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');

Readonly my $STYLE => 'color:#000000;font-size:10px;line-height:125%;font-family:sans-serif;display:inline';


=encoding utf8

=for stopwords Wenner merchantability perlartistic Inkscape px SVG


=head1 NAME

Comic::Out::Copyright - Adds a copyright or license note to a comic.

This module works on the generated F<.svg> file for each language.


=head1 SYNOPSIS

    my $copyright = Comic::Out::Copyright->new(%settings);
    $copyright->generate($comic);


=head1 DESCRIPTION

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Copyright.

Parameters:

=over 4

=item * B<%settings> settings hash.

=back

The note to add is given like this:

    my $copyright = Comic::Out::Copyright->new(
        'text' => {
            'English': 'beercomics.com -- CC BY-NC-SA 4.0'
        },
        'style' => 'font-family: sans-serif; font-size: 10px',
        'label_prefix' => 'Copyright',
        'id_prefix' => 'Copyright',
    );

The arguments are:

=over 4

=item * B<%text> (mandatory) the actual copyright or license text to insert
    in each language.

=item * B<$style> (optional) the style attribute for that inserted text.
    Anything legal in SVG is fair game. Defaults to black sans-serif in
    10 pixel size.

=item * B<label_prefix> prefix for the new generated Inkscape layer's label
    attribute. See C<id_prefix> below.

=item * B<<id_prefix> prefix for the new generated Inkscape layer's id
    attribute. Defaults to "Copyright". The language will be appended to
    this. This allows changing label and id in case you already have layers
    named e.g., C<CopyrightEnglish>.

=back

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->needs('text', 'HASH');
    $self->optional('style', '', $STYLE);
    $self->optional('label_prefix', '', 'Copyright');
    $self->optional('id_prefix', '', 'Copyright');
    $self->flag_extra_settings();

    return $self;
}


=head2 generate

Generates the copyright note in the given Comic. The text will be placed in
a new layer named from the given label_prefix plus the language name (with
the first letter capitalized), e.g., C<CopyrightEnglish>.

Parameters:

=over 4

=item * B<$comic> Comic to which to add the copyright notice.

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    my $svg = $comic->{dom};
    foreach my $language ($comic->languages()) {
        unless ($self->{settings}->{text}->{$language}) {
            croak("No $language Comic::Out::Copyright text configured");
        }

        my $id = "$self->{settings}->{id_prefix}$language";
        my $label = "$self->{settings}->{label_prefix}$language";

        my $payload = XML::LibXML::Text->new($self->{settings}->{text}->{$language});
        my $tspan = XML::LibXML::Element->new('tspan');
        $tspan->setAttribute('sodipodi:role', 'line');
        $tspan->appendChild($payload);

        my $text = XML::LibXML::Element->new('text');
        my ($x, $y, $transform) = _where_to_place_the_text($comic);
        $text->setAttribute('x', $x);
        $text->setAttribute('y', $y);
        $text->setAttribute('id', $id);
        $text->setAttribute('xml:space', 'preserve');

        my $style = $self->{settings}->{style};
        $text->setAttribute('style', $style);
        $text->setAttribute('transform', $transform) if ($transform);
        $text->appendChild($tspan);

        my $layer = XML::LibXML::Element->new('g');
        $layer->setNamespace('http://www.w3.org/2000/svg');
        $layer->setNamespace('http://www.inkscape.org/namespaces/inkscape', 'inkscape', 0);
        $layer->setAttribute('inkscape:groupmode', 'layer');
        $layer->setAttributeNS('http://www.inkscape.org/namespaces/inkscape', 'label', $label);
        $layer->setAttribute('style', 'display:inline');
        $layer->setAttribute('id', $id);
        $layer->appendChild($text);

        my $root = $svg->documentElement();
        $root->appendChild($layer);
    }

    return;
}


sub _where_to_place_the_text {
    my ($comic) = @ARG;

    Readonly my $SPACING => 2;
    my ($x, $y, $transform);
    my @frames = $comic->all_frames_sorted();

    if (@frames == 0) {
        # If the comic has no frames, place the text at the bottom.
        # Ask Inkscape about the drawing size.
        my $xpos = _inkscape_query($comic, 'X');
        my $ypos = _inkscape_query($comic, 'Y');
        $x = $xpos;
        $y = $ypos;
    }
    elsif (@frames == 1) {
        # If there is only one frame, place the text at the bottom left
        # corner just inside the frame.
        $x = $frames[0]->getAttribute('x') + $SPACING;
        $y = $frames[0]->getAttribute('y') + $frames[0]->getAttribute('height') - $SPACING;
    }
    elsif (_frames_in_rows(@frames)) {
        # Prefer putting the text between two rows of frames so that it's
        # easier to read.
        $x = $frames[-1]->getAttribute('x');
        $y = $frames[-1]->getAttribute('y') - $SPACING;
    }
    else {
        # If there are no rows of frames but more than two frames, put the text
        # between the first two frames, rotated 90 degrees.
        ($x, $y) = _bottom_right($comic);
        $x = $frames[0]->getAttribute('x') + $frames[0]->getAttribute('width') + $SPACING;
        $y = $frames[0]->getAttribute('y');
        $transform = "rotate(90, $x, $y)";
    }

    return ($x, $y, $transform);
}


sub _inkscape_query {
    # uncoverable subroutine
    my ($comic, $what) = @ARG; # uncoverable statement
    ## no critic(InputOutput::ProhibitBacktickOperators)
    return `inkscape -$what $comic->{srcFile}`; # uncoverable statement
    ## use critic
}


sub _bottom_right {
    my ($comic) = @ARG;

    my @frames = $comic->all_frames_sorted();
    my $bottom_right = $frames[-1];
    # from 0/0, x increases to right, y increases to the bottom
    return ($bottom_right->getAttribute('x') + $bottom_right->getAttribute('width'),
        $bottom_right->getAttribute('y'));
}


sub _frames_in_rows {
    my @frames = @ARG;

    my $prev = shift @frames;
    foreach my $frame (@frames) {
        my $off_by = $frame->getAttribute('y') - $prev->getAttribute('y');
        if (abs $off_by > $Comic::Consts::FRAME_SPACING) {
            return 1;
        }
        $prev = $frame;
    }
    return 0;
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
