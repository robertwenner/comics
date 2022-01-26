package Comic::Out::SvgPerLanguage;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;

use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords Wenner merchantability perlartistic MetaEnglish Scalable


=head1 NAME

Comic::Out::SvgPerLanguage - Generates a new Scalable Vector Graphics
(F<.svg>) file for each language in the given Comic. That F<.svg> shows the
layers common for all languages plus the ones for that language.

Other modules may work with the generated F<.svg> files, for example to
convert to other image formats per language.


=head1 SYNOPSIS

    my $svg = Comic::Out::SvgPerLanguage->new(%settings);
    $svg->generate($comic);


=head1 DESCRIPTION

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::SvgPerLanguage.

Parameters:

=over 4

=item * B<%settings> Hash reference to settings.

=back

The passed settings can specify the output directory (C<outdir>) and
optionally the name(s) of layers to exclude.

For example:

    my %settings = (
        'outdir' => 'generated/tmp/svg',
        'drop_layers' => ['Raw'],
    );
    my $svg = Comic::Out::SvgPerLanguage(%settings);

The F<.svg>s will be placed in language-specific directories under the given
C<outdir>. The names are derived from the Comic's titles in the respective
languages.

The final file names will be placed in the Comic as a C<SvgPerLanguage> hash
with language names (e.g., "English") as keys and a value of the F<.svg>
file's path (starting with C<outdir>) and name.

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->needs('outdir', 'directory');
    $self->optional('drop_layers', 'array-or-scalar', []);
    $self->flag_extra_settings();

    return $self;
}


=head2 generate

Generates the F<.svg>s for all languages in the given Comic.

The F<.svg> file name will be derived from the title of the comic. The
F<.svg> file will be placed in a per-language directory under the configured
C<outdir>.

Inkscape files must have meta data matching the layer names, e.g., "English"
in the meta data and an "English" layer and an "MetaEnglish" layer.

Parameters:

=over 4

=item * B<$comic> Comic for which to write the F<.svg> files.

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->languages()) {
        my $dir = $self->{settings}->{outdir} . "$language/";
        my $svg_file = Comic::make_dir($dir) . "$comic->{baseName}{$language}.svg";
        $comic->{svgFile}{$language} = $svg_file;

        next if (Comic::up_to_date($comic->{srcFile}, $svg_file));

        _flip_language_layers($comic, $language);
        $self->_write_svg_file($comic, $svg_file);
    }
    return;
}


sub _flip_language_layers {
    my ($comic, $language) = @ARG;

    # Hide all but current language layers
    my $had_lang = 0;
    foreach my $layer ($comic->get_all_layers()) {
        my $label = $layer->{'inkscape:label'};
        $layer->{'style'} = 'display:inline' unless (defined($layer->{'style'}));
        foreach my $other_lang ($comic->languages()) {
            # Turn off all meta layers and all other languages
            if ($label =~ m/$other_lang$/ || $label =~ m/^Meta/) {
                $layer->{'style'} =~ s{\bdisplay:inline\b}{display:none};
            }
        }
        # Make sure the right language layer is visible
        if ($label =~ m/$language$/ && $label !~ m/Meta/) {
            $layer->{'style'} =~ s{\bdisplay:none\b}{display:inline};
            $had_lang = 1;
        }
    }
    unless ($had_lang) {
        $comic->keel_over("Comic::Out::SvgPerLanguage: No $language layer");
    }
    return;
}


sub _write_svg_file {
    my ($self, $comic, $svg_file) = @ARG;

    _drop_top_level_layers($comic->{dom}, @{$self->{settings}->{'drop_layers'}});
    _write($comic->{dom}, $svg_file);
    return;
}


sub _drop_top_level_layers {
    my ($svg, @layers) = @ARG;

    my %wanted = map { $_ => 1 } @layers;
    my $root = $svg->documentElement();
    foreach my $node ($root->childNodes()) {
        if ($node->nodeName() eq 'g'
        && ($node->getAttribute('inkscape:groupmode') || '') eq 'layer'
        && $wanted{$node->getAttribute('inkscape:label' || '')}) {
            $root->removeChild($node);
        }
    }
    return;
}


sub _write {
    # uncoverable subroutine
    my ($svg, $file) = @ARG; # uncoverable statement

    $svg->toFile($file); # uncoverable statement
    return; # uncoverable statement
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
