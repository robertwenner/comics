package Comic;

use strict;
use warnings;

use Readonly;
use English '-no_match_vars';
use utf8;
use base qw(Exporter);
use POSIX;
use Carp;
use autodie;
use DateTime;
use File::Path qw(make_path);
use File::Temp qw/tempfile/;
use File::Basename;
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use XML::LibXML;
use XML::LibXML::XPathContext;
use JSON;
use HTML::Entities;
use Image::PNG;
use Template;


use version; our $VERSION = qv('0.0.2');

=for stopwords Inkscape inkscape html SVG svg PNG png Wenner MERCHANTABILITY perlartistic


=head1 NAME

Comic - Converts SVG comics to png by language and creates HTML pages.


=head1 VERSION

This document refers to version 0.0.2.


=head1 SYNOPSIS

    use Comic;

    my %languages = (
        "Deutsch" => "de",
        "English" => "en",
    );

    foreach my $file (@ARGV) {
        my $c = Comic->new($file);
        $c->export_png(%languages);
        $c->export_html(%languages);
    }


=head1 DESCRIPTION

From on an Inkscape SVG file, exports language layers to create per language
PNG files. Creates a transcript per language for search engines.

=cut


# XPath default namespace name.
Readonly our $DEFAULT_NAMESPACE => 'defNs';
# Tolerance in Inkscape units when looking for frames.
Readonly our $FRAME_TOLERANCE => 5;
# How to mark a comic as not publishable, so that the converter can flag it.
Readonly our $DONT_PUBLISH => 'DONT_PUBLISH';


# Whether to transform SVG coordinates if the transform atttribute is used.
# This may be needed for fancy texts (tilted or on a path) so that the new
# translated coordinates can be sorted as expected for the comic's transcript.
# However, it may be easier to just add invisible frames to force a text
# order in the comic.
Readonly our $TRANSFORM => 1;


my %text = (
    domain => {
        'English' => 'beercomics.com',
        'Deutsch' => 'biercomics.de',
    },
    langLink => {
        'English' => 'english version of this comic',
        'Deutsch' => 'deutsche Version dieses Comics',
    },
    keywords => {
        'English' => 'beer, comic',
        'Deutsch' => 'Bier, Comic',
    },
    templateFile => {
        'English' => 'web/english/comic-page.templ',
        'Deutsch' => 'web/deutsch/comic-page.templ',
    },
    licensePage => {
        'English' => 'about/license.html',
        'Deutsch' => 'ueber/lizenz.html',
    },
);


my %counts;
my %titles;
my @comics;


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic from an Inkscape SVG file.

=over 4

    =item B<$path/file> path and file name to the SVG input file.

=back

=cut

sub new {
    my ($class, $file, %options) = @ARG;
    my $self = bless{}, $class;
    $self->{options} = {
        $TRANSFORM => 1,
        %options
    };
    $self->_load($file);
    return $self;
}


sub _load {
    my ($self, $file) = @ARG;

    $self->{file} = $file;
    $self->{dom} = XML::LibXML->load_xml(string => _slurp($file));
    $self->{xpath} = XML::LibXML::XPathContext->new($self->{dom});
    $self->{xpath}->registerNs($DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $meta_xpath = _build_xpath('metadata/rdf:RDF/cc:Work/dc:description/text()');
    my $meta_data = join ' ', $self->{xpath}->findnodes($meta_xpath);
    $self->{meta_data} = from_json($meta_data);
    $self->{modified} = DateTime->from_epoch(epoch => _mtime($file))->ymd;
    push @comics, $self;
    return;
}


sub _slurp {
    my ($file) = @ARG;

    open my $F, '<', $file or croak "Cannot open $file: $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $contents = <$F>;
    close $F or croak "Cannot close $file: $OS_ERROR";
    return $contents;
}


sub _mtime {
    my ($file) = @ARG;

    Readonly my $MTIME => 9;
    return (stat $file)[$MTIME];
}


=head2 export_png

Exports PNGs for the given languages.

The png file will be the lower case title of the comic, limited to ASCII
only characters. It will be placed in F<generated/web/$language/>.

Parameters:

=over 4

    =item B<%languages> hash of long language name (e.g., "English") to
        short language name (e.g., "en"). The long language name must be
        used in the Inkscape layer names and the JSON meta data.

        This code will only work on the languages passed in this hash,
        even if additional languages are present in the SVG. Specifying a
        language that the SVG does not have is fine, you just don't get
        any output (png, transcript) for it.

=back

=cut

sub export_png {
    my ($self, %languages) = @ARG;

    foreach my $language (keys %languages) {
        next if $self->_not_for($language);

        $counts{'comics'}{$language}++;

        $self->_sanity_checks($language);
        $self->_check_dont_publish($language);
        $self->_check_tags('tags', $language);
        $self->_check_tags('people', $language);

        $self->_flip_language_layers($language, keys %languages);
        $self->_svg_to_png($language, $self->_write_temp_svg_file());
    }
    $self->_count_tags();
    return;
}


sub _sanity_checks {
    my ($self, $language) = @ARG;

    my $title = $self->{meta_data}->{title}->{$language};
    my $key = lc "$language\n$title";
    $key =~ s/^\s+//;
    $key =~ s/\s+$//;
    $key =~ s/\s+/ /g;
    if (defined $titles{$key}) {
        if ($titles{$key} ne $self->{file}) {
            croak("Duplicated $language title '$title' in $titles{$key} and $self->{file}");
        }
    }
    $titles{$key} = $self->{file};
    return;
}


sub _check_dont_publish {
    my ($self) = @ARG;

    _check_json('', $self->{meta_data});

    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $all_layers = _build_xpath('g[@inkscape:groupmode="layer"]');
    ## use critic
    foreach my $layer ($self->{xpath}->findnodes($all_layers)) {
        my $text = $layer->textContent();
        my $label = $layer->{'inkscape:label'};
        if ($text =~ m/(\b$DONT_PUBLISH\b[^\n\r]*)/m) {
            croak "In layer $label: $1";
        }
    }
    return;
}


sub _check_json {
    my ($where, $what) = @ARG;

    if (ref($what) eq 'HASH') {
        foreach my $key (keys %{$what}) {
            _check_json("$where > $key", $what->{$key});
        }
    }
    elsif (ref($what) eq 'ARRAY') {
        for my $i (0 .. $#{$what}) {
            _check_json($where . '[' . ($i + 1) . ']', $what->[$i]);
        }
    }
    elsif ($what =~ m/$DONT_PUBLISH/m) {
        croak "In JSON$where: $what";
    }
    return;
}


sub _check_tags {
    my ($self, $what, $language) = @ARG;

    foreach my $tag (@{$self->{meta_data}->{$what}->{$language}}) {
        croak("No $language $what") unless(defined $tag);
        croak("Empty $language $what") if ($tag =~ m/^\s*$/);
    }
    return;
}


sub _count_tags {
    my ($self) = @ARG;

    foreach my $what ('tags', 'people') {
        foreach my $language (keys %{$self->{meta_data}->{$what}}) {
            foreach my $val (@{$self->{meta_data}->{$what}->{$language}}) {
                $counts{$what}{$language}{$val}++;
            }
        }
    }
    return;
}


sub _flip_language_layers {
    my ($self, $language, @languages) = @ARG;

    # Hide all but current language layers
    my $had_lang = 0;
    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $all_layers = _build_xpath('g[@inkscape:groupmode="layer"]');
    ## use critic
    foreach my $layer ($self->{xpath}->findnodes($all_layers)) {
        my $label = $layer->{'inkscape:label'};
        foreach my $other_lang (@languages) {
            # Turn off all meta layers and all other languages
            if ($label =~ m/$other_lang$/ || $label =~ m/^Meta/) {
                $layer->{'style'} = 'display:none';
            }
        }
        # Make sure the right language layer is visible
        if ($label =~ m/$language$/ && $label !~ m/Meta/) {
            $layer->{'style'} = 'display:inline';
            $had_lang = 1;
        }
    }
    unless ($had_lang) {
        croak "No $language layer";
    }
}


sub _build_xpath {
    my (@fragments) = @ARG;

    my $xpath = "/$DEFAULT_NAMESPACE:svg";
    foreach my $p (@fragments) {
        $xpath .= "/$DEFAULT_NAMESPACE:$p";
    }
    return $xpath;
}


sub _write_temp_svg_file {
    my ($self) = @ARG;

    my ($handle, $temp_file_name) = tempfile(SUFFIX => '.svg');
    $self->{dom}->toFile($temp_file_name);
    return $temp_file_name
}


sub _svg_to_png {
    my ($self, $language, $svg_file) = @ARG;

    my $png_file = $self->_make_file_name($language, 'web', 'png');
    my $cmd = "inkscape --without-gui --file=$svg_file";
    $cmd .= ' --g-fatal-warnings';
    $cmd .= " --export-png=$png_file --export-area-drawing --export-background=#ffffff";
    system($cmd) && croak("Could not run $cmd: $OS_ERROR");

    my $png = Image::PNG->new();
    $png->read($png_file);
    $self->{height} = $png->height;
    $self->{width} = $png->width;
    return;
}


sub _make_file_name {
    my ($self, $language, $where, $ext) = @ARG;

    my $dir = "generated/$where/" . lc $language;
    File::Path::make_path($dir) or croak("Cannot mkdirs $dir: $OS_ERROR") unless(-d $dir);
    return "$dir/" . $self->_normalized_title($language) . ".$ext";
}


sub _make_url {
    my ($self, $language, $ext) = @ARG;

    return "https://$text{domain}{$language}/comics/"
        . $self->_normalized_title($language) . ".$ext";
}


sub _normalized_title {
    my ($self, $language) = @ARG;

    my $title = $self->{meta_data}->{title}->{$language};
    croak "No $language title in $self->{file}" unless($title);
    $title =~ s/\s/-/g;
    $title =~ s/[^\w\d_-]//gi;
    return lc $title;
}


=head2 export_all_html

Generates a HTML page for each Comics that have been loaded.

The HTML page will be the same name as the generated PNG, with a .html
extension and will be placed next to it.

Parameters:

=over 4

    =item B<%languages> hash of short language name (e.g., en for English and
        de for German) to long language name.

=back

=cut

sub export_all_html {
    my (%languages) = @ARG;

    my @sorted = sort _compare @comics;
    # Would be nice to do this incrementally...
    foreach my $i (0..@sorted - 1) {
        my $comic = $sorted[$i];
        foreach my $language (keys %languages) {
            next if ($comic->_not_for($language));

            my $first_comic = _find_first($language, $i, @sorted);
            my $prev_comic = _find_prev($language, $i, @sorted);
            my $next_comic = _find_next($language, $i, @sorted);
            my $last_comic = _find_last($language, $i, @sorted);
            # FIXME replace all these basename(make_file...) calls with $self->{basename}
            if ($first_comic) {
                $comic->{'first'} = basename($first_comic->_make_file_name($language, '', 'html'));
            }
            else {
                $comic->{'first'} = 0;
            }
            if ($prev_comic) {
                $comic->{'prev'} = basename($prev_comic->_make_file_name($language, '', 'html'));
            }
            else {
                $comic->{'prev'} = 0;
            }
            if ($next_comic) {
                $comic->{'next'} = basename($next_comic->_make_file_name($language, '', 'html'));
            }
            else {
                $comic->{'next'} = 0;
            }
            if ($last_comic) {
                $comic->{'last'} = basename($last_comic->_make_file_name($language, '', 'html'));
            }
            else {
                $comic->{'last'} = 0;
            }

            $comic->_export_language_html($language, %languages);
            $comic->_write_sitemap_xml_fragment($language);
        }
    }
    return;
}


sub _find_first {
    my ($language, $pos, @sorted) = @_;

    foreach my $i (0 .. $pos - 1) {
        my $comic = $sorted[$i];
        return $comic unless ($comic->_not_for($language));
    }
    return 0;
}


sub _find_prev {
    my ($language, $pos, @sorted) = @_;

    while (--$pos >= 0) {
        my $comic = $sorted[$pos];
        return $comic unless ($comic->_not_for($language));
    }
    return 0;
}


sub _find_next {
    my ($language, $pos, @sorted) = @_;

    while (++$pos < @sorted) {
        my $comic = $sorted[$pos];
        return $comic unless ($comic->_not_for($language));
    }
    return 0;
}


sub _find_last {
    my ($language, $pos, @sorted) = @_;

    foreach my $i (reverse $pos + 1 .. @sorted - 1) {
        my $comic = $sorted[$i];
        return $comic unless ($comic->_not_for($language));
    }
    return 0;
}


sub _export_language_html {
    my ($self, $language, %languages) = @ARG;

    # If the comic has no title for the given language, assume it does not
    # have language layers either and don't export a transcript.
    return if $self->_not_for($language);

    my $page = $self->_make_file_name($language, 'web', 'html');
    open my $F, '>', $page or croak "Cannot write $page: $OS_ERROR";
    $self->_do_export_html($F, $language, %languages);
    close $F or croak "Cannot close $page: $OS_ERROR";
    return;
}


sub _not_for {
    my ($self, $language) = @ARG;
    return !$self->{meta_data}->{title}->{$language};
}


sub _do_export_html {
    my ($self, $F, $language, %languages) = @ARG;

    my %vars;
    my $title = $self->{meta_data}->{title}->{$language};
    # SVG, being XML, needs to encode XML special characters, but does not do
    # HTML encoding. So first reverse the XML encoding, then apply any HTML
    # encoding.
    $vars{title} = encode_entities(decode_entities($title));
    $vars{png_file} = basename($self->_make_file_name($language, 'web', 'png'));
    $vars{modified} = $self->{modified};
    $vars{height} = $self->{height};
    $vars{width} = $self->{width};
    $vars{'first'} = $self->{'first'};
    $vars{'prev'} = $self->{'prev'};
    $vars{'next'} = $self->{'next'};
    $vars{'last'} = $self->{'last'};

    my $language_links = '';
    foreach my $l (sort keys %languages) {
        next if ($l eq $language);

        if ($self->{meta_data}->{title}->{$l}) {
            my $href = $self->_make_url($l, 'png');
            my $alt = $text{langLink}{$l};
            $language_links .= "<a href=\"$href\" alt=\"$alt\">" . uc $l . '</a> ';
        }
    }

    $vars{transcript} = '';
    foreach my $t ($self->_texts_for($language)) {
        $vars{transcript} .= '<p>' . encode_entities($t) . "</p>\n";
    }

    $vars{description} = encode_entities(
        $text{keywords}{$language} . ', ' .
        join ', ', @{$self->{meta_data}->{tags}->{$language}});

    print {$F} $self->_templatize(_slurp($text{templateFile}{$language}), %vars)
        or croak "Error writing HTML: $OS_ERROR";
    return;
}


sub _texts_for {
    my ($self, $language) = @ARG;

    $self->_find_frames();
    my @texts;
    foreach my $node (sort { $self->_text_pos_sort($a, $b) } $self->{xpath}->findnodes(_text($language))) {
        my XML::LibXML::Node $tspan = $node->firstChild();
        my $text = '';
        do {
            $text .= $tspan->textContent() . ' ';
            $tspan = $tspan->nextSibling();
        }
        while ($tspan);
        $text =~ s/-\s+/-/mg;
        $text =~ s/ +/ /mg;
        $text =~ s/^\s+//mg;
        $text =~ s/\s+$//mg;

        if ($text eq '') {
            my $layer = $node->parentNode->{'inkscape:label'};
            croak "Empty text in $layer with ID $node->{id}";
        }
        push @texts, $text;
    }
    return @texts;
}


sub _find_frames {
    my ($self) = @ARG;

    # Find the frames in the comic. Remember the top of the frames.
    # Assume frames that have their top within a certain $FRAME_TOLERANCE
    # distance from each other are meant to be at the same position.
    my @frame_tops;
    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $frame_xpath = _build_xpath('g[@inkscape:label="Rahmen"]', 'rect');
    ## use critic
    foreach my $f ($self->{xpath}->findnodes($frame_xpath)) {
        my $y = floor($f->getAttribute('y'));
        my $found = 0;
        foreach my $ff (@frame_tops) {
            $found = 1 if ($ff + $FRAME_TOLERANCE > $y && $ff - $FRAME_TOLERANCE < $y);
        }
        push @frame_tops, $y unless($found);
    }
    @{$self->{frame_tops}} = sort @frame_tops;
    return;
}


sub _text_pos_sort {
    my ($self, $a, $b) = @ARG;
    # Inkscape coordinate system has 0/0 as bottom left corner
    my $ya = $self->_pos_to_frame($self->_transformed($a, 'y'));
    my $yb = $self->_pos_to_frame($self->_transformed($b, 'y'));
    return $ya <=> $yb
        || $self->_transformed($a, 'x') <=> $self->_transformed($b, 'x');
}


sub _transformed {
    my ($self, $node, $attribute) = @ARG;

    my $transform = $node->getAttribute('transform');
    if (!$transform || !$self->{options}{$TRANSFORM}) {
        return $node->getAttribute($attribute);
    }

    ## no critic(RegularExpressions::ProhibitCaptureWithoutTest)
    # Perl::Critic does not understand the croak.
    croak 'Cannot handle multiple transformations' if ($transform !~ m/^(\w+)\(([^)]+)\)$/);
    ## no critic(RegularExpressions::ProhibitCaptureWithoutTest)
    # Perl::Critic does not understand the croak.
    my ($operation, $params) = ($1, $2);
    ## use critic
    my ($a, $b, $c, $d, $e, $f);
    # Inkscape sources:
    # Operations in Inkscape's src/cvg/svg-affine.cpp
    # Actual matrix math in src/2geom/affine.cpp
    if ($operation eq 'matrix') {
        ## no critic(Variables::RequireLocalizedPunctuationVars)
        ($a, $b, $c, $d, $e, $f) = split /,/, $params;
        ## use critic
    }
    elsif ($operation eq 'scale') {
        my ($sx, $sy) = split /,/, $params;
        ## no critic(Variables::RequireLocalizedPunctuationVars)
        ($a, $b, $c, $d, $e, $f) = ($sx, 0, 0, $sy, 0, 0);
        ## use critic
    }
    else {
        croak "Unsupported operation $operation";
    }
    my $x = $node->getAttribute('x');
    my $y = $node->getAttribute('y');
    # http://www.w3.org/TR/SVG/coords.html#TransformMatrixDefined
    # a c e   x
    # b d f * y
    # 0 0 1   1
    # FIXME: Ignores inkscape:transform-center-x and inkscape:transform-center-y
    # attributes.
    return $a * $x + $c * $y if ($attribute eq 'x');
    return $b * $x + $d * $y if ($attribute eq 'y');
    croak "Unsupported attribute $attribute to transform";
}


sub _text {
    my ($label) = @ARG;
    return _build_xpath(
        "g[\@inkscape:label=\"$label\" or \@inkscape:label=\"Meta$label\"]/",
        'text');
}


sub _pos_to_frame {
    my ($self, $y) = @ARG;

    for my $i (0..@{$self->{frame_tops}} - 1) {
        return $i if ($y < @{$self->{frame_tops}}[$i]);
    }
    return @{$self->{frame_tops}};
}


sub _templatize {
    my ($self, $template, %vars) = @ARG;

    my %options = (
        STRICT => 1,
    );
    my $t = Template->new(%options) ||
        croak('Cannot construct template: ' . Template->error());
    my $output = '';
    $t->process(\$template, \%vars, \$output) || croak $t->error();
    if ($output =~ m/(\[%\S*)/m) {
        croak "Unresolved template marker $1";
    }
    return $output;
}


sub _write_sitemap_xml_fragment {
    my ($self, $language) = @ARG;

    my $html = $self->_make_url($language, 'html');
    my $path = "https://$text{domain}{$language}/";
    my $png_file = basename($self->_make_file_name($language, 'web', 'png'));
    my $title = $self->{meta_data}->{title}{$language};
    my $fragment = $self->_make_file_name($language, 'tmp', 'xml');

    _write_file($fragment, <<"XML");
<url>
<loc>$html</loc>
<image:image>
<image:loc>${path}comics/$png_file</image:loc>
<image:title>$title</image:title>
<image:license>$path$text{licensePage}{$language}</image:license>
</image:image>
<lastmod>$self->{modified}</lastmod>
</url>
XML
    return;
}


sub _write_file {
    my ($file_name, $contents) = @ARG;

    open my $F, '>', $file_name or croak "Cannot write $file_name: $OS_ERROR";
    print {$F} $contents or croak "Cannot write to $file_name: $OS_ERROR";
    close $F or croak "Cannot close $file_name: $OS_ERROR";
    return;
}


## no critic(Subroutines::ProhibitSubroutinePrototypes, Subroutines::RequireArgUnpacking)
# Perl::Critic complains about the use of prototypes, and I agree, but this
# case is special, mentioned in perldoc -f sort:
#   # using a prototype allows you to use any comparison subroutine
#   # as a sort subroutine (including other package's subroutines)
#   package other;
#   sub backwards ($$) { $_[1] cmp $_[0]; }  # $a and $b are
#                                            # not set here
#   package main;
#   @new = sort other::backwards @old;
#
sub _compare($$) {
## use critic
    my $pub_a = $_[0]->{meta_data}->{published}{when} || '3000-01-01';
    my $pub_b = $_[1]->{meta_data}->{published}{when} || '3000-01-01';
    return $pub_a cmp $pub_b;
}


=head2 reset_statics

Helper to allow tests to clear internal static state.

=cut

sub reset_statics {
    %counts = ();
    @comics = ();
    return;
}


=head2 counts_of_in

Returns the counts of all 'what' in the given language.
This can be used for a tag cloud.

Parameters:

=over 4

    =item B<$what> what counts to get, e.g., "tags" or "people".

    =item B<$language> for what language, e.g., "English".

=back

Returned data depends on what was asked for. If asked for tags or people,
the result will be a hash of tag and person's name, respectively, to counts.
If asked for 'comics', it will return a single number (the number of comics
in that language).

=cut

sub counts_of_in {
    my ($what, $language) = @ARG;
    return $counts{$what}{$language};
}


1;


=head1 DIAGNOSTICS

None.


=head1 DEPENDENCIES

Inkscape 0.91.


=head1 CONFIGURATION AND ENVIRONMENT

The inkscape binary must be in the current $PATH.


=head1 INCOMPATIBILITIES

None known.


=head1 BUGS AND LIMITATIONS

Works only with Inkscape files.

No bugs have been reported.

Please report any bugs or feature requests to C<< <robert.wenner@posteo.de> >>


=head1 AUTHOR

Robert Wenner  C<< <robert.wenner@posteo.de> >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 - 2016, Robert Wenner C<< <robert.wenner@posteo.de> >>.
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
