package Comic::Out::Png;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use Readonly;
use File::Copy;

use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');

# Temp dir for per-langugage svg exports.
Readonly my $TEMPDIR => 'tmp';


=for stopwords Wenner merchantability perlartistic png whitespace metaenglish optipng

=head1 NAME

Comic::Out::Png - Generates a Portable Network Graphics (F<.png>) file for
the given Comic in each of the Comic's languages.

=head1 SYNOPSIS

    my $png = Comic::Out::Png->new(\%settings);
    $png->generate($comic);

=head1 DESCRIPTION

The template file name must be given in the configuration for each language
like this:

    {
        "Out": {
            "Png": {
                "outdir": "generated/web/comics",
                "tmpdir": "generated/tmp",
            }
        }
    }

The F<.png>s will be placed in the given C<outdir>. The names are derived
from the Comic's titles in their languages.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Png.

Parameters:

=over 4

=item * B<$settings> Hash reference to settings.

=back

The passed settings need to specify the output directory (C<outdir>).

For example:

    my $settings = {
        'Out' => {
            'Png' => {
                'outdir' => 'generated',
            }
        }
    }
    my $png = Comic::Out::Png($settings);

=cut


sub new {
    my ($class, $settings) = @ARG;
    my $self = bless{}, $class;

    croak('No Png configuration') unless ($settings->{Png});
    %{$self->{settings}} = %{$settings->{Png}};

    croak('Must specify Png.outdir output directory') unless ($self->{settings}->{outdir});
    $self->{settings}->{outdir} .= q{/} unless ($self->{settings}->{outdir} =~ m{/$});

    # Devel::Cover does not see that $TEMPDIR is an always set const:
    # uncoverable condition right
    # uncoverable condition false
    $self->{settings}->{tempdir} ||= $TEMPDIR;
    $self->{inkscape_version} = undef;

    return $self;
}


=head2 generate

Generates the F<.png>s for all languages in the given Comic.

The F<.png> file will be derived from the title of the comic, limited to
letters, numbers, and hyphens only. Whitespace is replaced by hyphens. The
F<.png> file will be placed in a per-language directory under the configured
C<outdir>.

Inkscape files must have meta data matching layer names, e.g., "English" in
the meta data and an "English" layer and an "MetaEnglish" layer.

If C<optipng> is installed, it is run on the produced F<.png> files.

Parameters:

=over 4

=item * B<$comic> Comic for which to write he F<.png> files.

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->languages()) {
        my $png_file = "$comic->{dirName}{$language}/$comic->{pngFile}{$language}";
        # TODO pull backlog out of here, write only published pngs
        # OR pass a published and a not published outdir
        # OR pass a hash of outdir to coderef to decide which png goes where --- yay for overengineering!
        my $backlog_png = "$comic->{backlogPath}{$language}/$comic->{pngFile}{$language}" || '';

        if (Comic::up_to_date($comic->{srcFile}, $backlog_png)) {
            _move($backlog_png, $png_file) or $comic->keel_over("Cannot move $backlog_png to $png_file: $OS_ERROR");
        }

        unless (Comic::up_to_date($comic->{srcFile}, $png_file)) {
            _flip_language_layers($comic, $language);
            my $language_svg = $self->_write_temp_svg_file($comic, $language);
            $self->_svg_to_png($comic, $language, $language_svg, $png_file);
            _optimize_png($comic, $png_file);
        }
        _get_png_info($comic, $png_file, $language);
    }
    return;
}


sub _move {
    # uncoverable subroutine
    return File::Copy::move(@ARG); # uncoverable statement
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
        $comic->keel_over("no $language layer");
    }
    return;
}


sub _write_temp_svg_file {
    my ($self, $comic, $language) = @ARG;

    my $dir = $self->{settings}->{tempdir} . lc $language . '/svg/';
    my $temp_file_name = Comic::make_dir($dir) . "$comic->{baseName}{$language}.svg";
    my $svg = $comic->copy_svg();
    _drop_top_level_layers($svg, 'Raw');
    $comic->_insert_url($svg, $language);
    $svg->toFile($temp_file_name);
    return $temp_file_name;
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


sub _svg_to_png {
    my ($self, $comic, $language, $svg_file, $png_file) = @ARG;

    my $version = $self->_get_inkscape_version($comic);
    my $export_cmd = _build_inkscape_command($comic, $svg_file, $png_file, $version);
    _system($export_cmd) && $comic->keel_over("could not export: $export_cmd: $OS_ERROR");

    my $tool = Image::ExifTool->new();
    # Add data inferred from comic
    my %meta_data = (
        'Title' => $comic->{meta_data}->{title}->{$language},
        'Description' => join('', $comic->get_transcript($language)),
        'CreationTime' => $comic->{modified},
        'URL' => $comic->{url}{$language},
    );
    foreach my $m (keys %meta_data) {
        _set_png_meta($comic, $tool, $m, $meta_data{$m});
    }
    # Add global settings
    my %settings = %{$comic->{settings}};
    foreach my $key (qw/Author Artist Copyright/) {
        if ($settings{$key}) {
            _set_png_meta($comic, $tool, $key, $settings{$key});
        }
    }
    # Add data explicitly overriden in comic meta data
    my $svg_meta = $comic->{meta_data}->{'png-meta-data'};
    if (ref($svg_meta) eq 'HASH') {
        foreach my $key (keys %{$svg_meta}) {
            _set_png_meta($comic, $tool, $key, ${${svg_meta}}{$key});
        }
    }
    # Finally write png meta data
    my $rc = $tool->WriteInfo($png_file);
    if ($rc != 1) {
        $comic->keel_over('cannot write PNG meta data: ' . $tool->GetValue('Error'));
    }
    return;
}


sub _optimize_png {
    my ($comic, $png_file) = @ARG;

    # Shrink / optimize PNG
    my $shrink_cmd = "optipng --quiet $png_file";
    _system($shrink_cmd) && $comic->warning("Could not shrink: $shrink_cmd: $OS_ERROR");

    return;
}


sub _system {
    # uncoverable subroutine
    return system @ARG; # uncoverable statement
}


sub _get_png_info {
    my ($comic, $png_file, $language) = @_;

    my $tool = Image::ExifTool->new();
    my $info = $tool->ImageInfo($png_file);

    # @fixme should height and width be different per language?
    $comic->{height} = ${$info}{'ImageHeight'};
    $comic->{width} = ${$info}{'ImageWidth'};
    $comic->{pngSize}{$language} = _file_size($png_file);
    return;
}


sub _file_size {
    # uncoverable subroutine
    my ($name) = @_; # uncoverable statement

    Readonly my $SIZE => 7; # uncoverable statement
    return (stat $name)[$SIZE]; # uncoverable statement
}


sub _set_png_meta {
    my ($comic, $tool, $name, $value) = @ARG;

    my ($count_set, $error) = $tool->SetNewValue($name, $value);
    $comic->keel_over("Cannot set $name: $error") if ($error);
    return;
}


sub _query_inkscape_version {
    # uncoverable subroutine
    my ($comic) = @ARG; # uncoverable statement

    # Inkscape seems to print its plugins information to stderr, e.g.:
    #    Pango version: 1.46.0
    # Hence redirect stderr to /dev/null.

    ## no critic(InputOutput::ProhibitBacktickOperators)
    my $version = `inkscape --version 2>/dev/null`; # uncoverable statement
    ## use critic
    if ($OS_ERROR) { # uncoverable statement
        $comic->keel_over("Could not run Inkscape: $OS_ERROR"); # uncoverable statement
    }
    return $version; # uncoverable statement
}


sub _parse_inkscape_version {
    my ($comic, $inkscape_output) = @ARG;

    # Inkscape 0.92.5 (2060ec1f9f, 2020-04-08)
    # Inkscape 1.0 (4035a4fb49, 2020-05-01)
    # Inkscape 1.0.2 (e86c870879, 2021-01-15)
    if ($inkscape_output =~ m/^Inkscape\s+(\d+\.\d)/) {
        return $1;
    }
    $comic->keel_over("Cannot figure out Inkscape version from this:\n$inkscape_output");
    # PerlCritic doesn't know that keel_over doesn't return and the return statement
    # here is unreachable.
    return 'unknown';  # uncoverable statement
}


sub _get_inkscape_version {
    my ($self, $comic) = @ARG;

    unless (defined $self->{inkscape_version}) {
        $self->{inkscape_version} = $self->_parse_inkscape_version(_query_inkscape_version($comic));
    }
    return $self->{inkscape_version};
}


sub _build_inkscape_command {
    my ($comic, $svg_file, $png_file, $version) = @ARG;

    if ($version eq '0.9') {
        return 'inkscape --g-fatal-warnings --without-gui ' .
            "--file=$svg_file --export-png=$png_file " .
            '--export-area-drawing --export-background=#ffffff';
    }
    if ($version ne '1.0') {
        $comic->warning("Don't know Inkscape $version, hoping it's compatible to 1.0");
    }

    return 'inkscape --g-fatal-warnings ' .
        "--export-type=png --export-filename=$png_file " .
        "--export-area-drawing --export-background=#ffffff $svg_file";
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Comic module. Inkscape. optipng.


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
