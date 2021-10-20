package Comic::Out::Sizemap;

use strict;
use warnings;
use utf8;
use Locales unicode => 1;
use English '-no_match_vars';
use Scalar::Util qw(looks_like_number);
use File::Basename;
use Carp;
use Readonly;
use SVG;

use Comic::Out::Template;
use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');

Readonly my $SCALE => 0.3;
Readonly my $PUBLISHED_COLOR => 'green';
Readonly my $UNPUBLISHED_COLOR => 'blue';

Readonly my $MIN_SIZE_SENTINEL => 9_999_999;


=encoding utf8

=for stopwords Wenner merchantability perlartistic notFor


=head1 NAME

Comic::Out::Sizemap - Generates a map of different comic image sizes used.


=head1 SYNOPSIS

    my $sizemap = Comic::Out::Sizemap->new(%settings);
    $sizemap->generate_all(@comics);


=head1 DESCRIPTION

Generates a size map page for all comics, using a Perl L<Template> Toolkit
template. This is for the backlog or informational purposes, like when
figuring out which image size is frequently used.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Sizemap.

Parameters:

=over 4

=item * B<%settings> Hash of settings.

=back

The passed settings need to have the template file to work with and the output file.
The size map is language-independent, i.e., all languages end up in the same map.

For example:

    my %settings = (
        'template' => 'templates/sizemap.templ',
        'output' => 'generated/sizemap.html',
    );
    my $sitemap = Comic::Out::Sizemap(%settings);

Other supported settings are:

=over 4

=item * B<scale> factor by which to scale images in the map (for better
    overview), defaults to 0.3.

=item * B<published_color> in which color to draw frames for published
    comics. Use any legal SVG color value. Defaults to "green".

=item * B<unpublished_color> in which color to draw frames for unpublished
    comics. Use any legal SVG color value. Defaults to "blue".

=back

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->needs('template', 'scalar');
    $self->needs('outfile', 'scalar');
    $self->optional('scale', 'scalar', $SCALE);
    croak('Comic:Out::Sizemap.scale must be numeric') unless (looks_like_number($self->{settings}->{scale}));
    $self->optional('published_color', 'scalar', $PUBLISHED_COLOR);
    $self->optional('unpublished_color', 'scalar', $UNPUBLISHED_COLOR);
    $self->flag_extra_settings();

    return $self;
}


=head2 generate_all

Generates the size map for the given Comics.

Parameters:

=over 4

=item * B<@comics> Comics to include in the size map.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my $output = $self->{settings}->{outfile};
    my $template = $self->{settings}->{template};
    my %vars = $self->_aggregate(@comics);
    Comic::write_file($output, Comic::Out::Template::templatize('size map', $template, '', %vars));
    return;
}


sub _aggregate {
    my ($self, @comics) = @ARG;

    my %aggregate = _aggregate_comic_sizes(@comics);

    my $svg = SVG->new(
        width => $aggregate{width}{'max'} * $self->{settings}->{scale},
        height => $aggregate{height}{'max'} * $self->{settings}->{scale},
        -inline => 1,
        -printerror => 1,
        -raiseerror => 1);

    foreach my $comic (sort Comic::from_oldest_to_latest @comics) {
        my $color = $self->{settings}->{published_color};
        $color = $self->{settings}->{unpublished_color} if ($comic->not_yet_published());
        $svg->rectangle(x => 0, y => 0,
            width => $comic->{width} * $self->{settings}->{scale},
            height => $comic->{height} * $self->{settings}->{scale},
            id => basename("$comic->{srcFile}"),
            style => {
                'fill-opacity' => 0,
                'stroke-width' => '3',
                'stroke' => "$color",
            });
    }

    my %vars;
    foreach my $agg (qw(min max avg)) {
        foreach my $dim (qw(width height)) {
            if (!$aggregate{$dim}{$agg} || $aggregate{$dim}{$agg} == $MIN_SIZE_SENTINEL) {
                $vars{"$agg$dim"} = 'n/a';
            }
            else {
                $vars{"$agg$dim"} = $aggregate{$dim}{$agg};
            }
        }
    }
    $vars{'comics_by_width'} = [sort _by_width @comics];
    $vars{'comics_by_height'} = [sort _by_height @comics];
    $vars{svg} = $svg->xmlify();
    return %vars;
}


sub _aggregate_comic_sizes {
    my @comics = @ARG;

    my %aggregate;
    my %inits = (
        'min' => $MIN_SIZE_SENTINEL,
        'max' => 0,
        'avg' => 0,
    );
    foreach my $agg (qw(min max avg)) {
        foreach my $dim (qw(height width)) {
            $aggregate{$dim}{$agg} = $inits{$agg};
        }
    }
    my $count = 0;

    foreach my $comic (@comics) {
        $count++;
        foreach my $dim (qw(height width)) {
            if ($aggregate{$dim}{'min'} > $comic->{$dim}) {
                $aggregate{$dim}{'min'} = $comic->{$dim};
            }
            if ($aggregate{$dim}{'max'} < $comic->{$dim}) {
                $aggregate{$dim}{'max'} = $comic->{$dim};
            }
            $aggregate{$dim}{'avg'} += $comic->{$dim};
        }
    }

    foreach my $dim (qw(height width)) {
        if ($count != 0) {
            $aggregate{$dim}{'avg'} /= $count;
        }
    }

    return %aggregate;
}


## no critic(Subroutines::ProhibitSubroutinePrototypes, Subroutines::RequireArgUnpacking)
sub _by_width($$) {
## use critic
    return $_[0]->{width} <=> $_[1]->{width};
}


## no critic(Subroutines::ProhibitSubroutinePrototypes, Subroutines::RequireArgUnpacking)
sub _by_height($$) {
## use critic
    return $_[0]->{height} <=> $_[1]->{height};
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Comic module, L<Template>.


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

Copyright (c) 2016 - 2021, Robert Wenner C<< <rwenner@cpan.org> >>.
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
