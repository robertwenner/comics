package Comic;

use strict;
use warnings;

use utf8;
use base qw(Exporter);
use POSIX;
use Carp;
use autodie;
use DateTime;
use File::Path qw(make_path);
use File::Temp qw/tempfile/;
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use XML::LibXML;
use XML::LibXML::XPathContext;
use JSON;
use HTML::Entities;
use Image::PNG;
use Template;


use version; our $VERSION = qv('0.0.2');


=head1 NAME

Comic - Converts SVG comics to png by language and creates HTML pages.


=head1 SYNOPSIS

    use Comic;

    my %languages = (
        "Deutsch" => "de",
        "English" => "en",
    );

    foreach my $file (@ARGV) {
        my $c = Comic->new($file);
        $c->exportPng(%languages);
        $c->exportHtml(%languages);
    }


=head1 DESCRIPTION

From on an Inscape SVG file, exports language layers to create per language
PNG files. Creates a transcript per language for search engines.

=cut


use constant {
    # XPath default namespace name.
    DEFAULT_NAMESPACE => "defNs",
    # Tolerance in Inkscape units when looking for frames.
    FRAME_TOLERANCE => 5,
    # How to mark a comic as not publishable, so that the converter can flag
    # it.
    DONT_PUBLISH => 'DONT_PUBLISH',
};

our %options = (
    # Whether to transform SVG coordinates if the transform atttribute is used.
    # This may be needed for fancy texts (tilted or on a path) so that the new
    # translated coordinates can be sorted as expected for the comic's transcript.
    # However, it may be easier to just add invisible frames to force a text
    # order in the comic.
    TRANSFORM => 1,
);

my %text = (
    domain => {
        "English" => "beercomics.com",
        "Deutsch" => "biercomics.de",
    },
    langLink => {
        "English" => "english version of this comic",
        "Deutsch" => "deutsche Version dieses Comics",
    },
    keywords => {
        "English" => "beer, comic",
        "Deutsch" => "Bier, Comic",
    },
    templateFile => {
        "English" => "web/english/comic-page.templ",
        "Deutsch" => "web/deutsch/comic-page.templ",
    },
    licensePage => {
        "English" => "about/license.html",
        "Deutsch" => "ueber/lizenz.html",
    },
);

# our so that tests can reset these
our %counts;
my %titles;


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic from an Inkscape SVG file.

=over 4

    =item B<$path/file> path and file name to the SVG input file.

=back

=cut

sub new {
    my ($class, $file) = @_;
    my $self = bless{}, $class;
    $self->_load($file);
    return $self;
}


sub _load {
    my ($self, $file) = @_;

    $self->{file} = $file;
    $self->{dom} = XML::LibXML->load_xml(string => _slurp($file));
    $self->{xpath} = XML::LibXML::XPathContext->new($self->{dom});
    $self->{xpath}->registerNs(DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg'); 
    my $metaXpath = _buildXpath('metadata/rdf:RDF/cc:Work/dc:description/text()');
    my $metaData = join(" ", $self->{xpath}->findnodes($metaXpath));
    $self->{metaData} = from_json($metaData);
    $self->{modified} = DateTime->from_epoch(epoch => _mtime($file))->ymd;
}


sub _slurp {
    my ($file) = @_;

    open my $F, "<", $file or croak "Cannot open $file: $!";
    local $/ = undef;
    my $contents = <$F>;
    close $F or croak "Cannot close $file: $!";
    return $contents;
}


sub _mtime {
    my ($file) = @_;

    return (stat $file)[9];
}


=head2 exportPng

Exports PNGs for the given languages.

The png file will be the lowercased asciified title of the comic.
It will be placed in F<generated/web/$language/>.

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

sub exportPng {
    my ($self, %languages) = @_;

    foreach my $language (keys %languages) {
        next if $self->_notFor($language);

        $self->_sanityChecks($language);
        $self->_checkDontPublish($language);
        $self->_checkTags("tags", $language);
        $self->_checkTags("people", $language);

        $self->_flipLanguageLayers($language, keys (%languages));
        $self->_svgToPng($language, $self->_writeTempSvgFile());
    }
    $self->_countTags();
}


sub _sanityChecks {
    my ($self, $language) = @_;

    my $title = $self->{metaData}->{title}->{$language};
    my $key = lc("$language\n$title");
    $key =~ s/^\s+//;
    $key =~ s/\s+$//;
    $key =~ s/\s+/ /g;
    if (defined($titles{$key})) {
        if ($titles{$key} ne $self->{file}) {
            croak("Duplicated $language title '$title' in $titles{$key} and $self->{file}");
        }
    }
    $titles{$key} = $self->{file};
}


sub _checkDontPublish {
    my ($self) = @_;

    _checkJson("", $self->{metaData});

    my $allLayers = _buildXpath('g[@inkscape:groupmode="layer"]');
    foreach my $layer ($self->{xpath}->findnodes($allLayers)) {
        my $text = $layer->textContent();
        my $label = $layer->{"inkscape:label"};
        if ($text =~ m/(\bDONT_PUBLISH\b[^\n\r]*)/m) {
            croak "In layer $label: $1";
        }
    }
}


sub _checkJson {
    my ($where, $what) = @_;

    if (ref($what) eq 'HASH') {
        foreach my $key (keys %$what) {
            _checkJson("$where > $key", $what->{$key});
        }
    }
    elsif (ref($what) eq 'ARRAY') {
        for my $i (0 .. $#{$what}) {
            _checkJson("$where" . "[" . ($i + 1) . "]", $what->[$i]);
        }
    }
    elsif ($what =~ m/DONT_PUBLISH/m) {
        croak "In JSON$where: $what";
    }
}


sub _checkTags {
    my ($self, $what, $language) = @_;

    foreach my $tag (@{$self->{metaData}->{$what}->{$language}}) {
        croak("No $language $what") unless(defined($tag));
        croak("Empty $language $what") if ($tag =~ m/^\s*$/);
    }
}


sub _countTags {
    my ($self) = @_;

    foreach my $what ("tags", "people") {
        foreach my $language (keys %{$self->{metaData}->{$what}}) {
            foreach my $val (@{$self->{metaData}->{$what}->{$language}}) {
                $counts{$what}{$language}{$val}++;
            }
        }
    }
}


sub _flipLanguageLayers {
    my ($self, $language, @languages) = @_;

    # Hide all but current language layers
    my $hadLang = 0;
    my $allLayers = _buildXpath('g[@inkscape:groupmode="layer"]');
    foreach my $layer ($self->{xpath}->findnodes($allLayers)) {
        my $label = $layer->{"inkscape:label"};
        foreach my $otherLang (@languages) {
            # Turn off all meta layers and all other languages
            if ($label =~ m/$otherLang$/ || $label =~ m/^Meta/) {
                $layer->{"style"} = "display:none";
            }
        }
        # Make sure the right language layer is visible
        if ($label =~ m/$language$/ && $label !~ m/Meta/) {
            $layer->{"style"} = "display:inline";
            $hadLang = 1;
        }
    }
    unless ($hadLang) {
        if ($self->{file} =~ m@/([a-z]{2,3})/[^/]+.svg$@) {
            return if ($1 ne $language || $1 eq "div");
        }
        croak "No $language layer";
    }
}


sub _buildXpath {
    my $xpath = '/' . DEFAULT_NAMESPACE . ':svg';
    foreach my $p (@_) {
        $xpath .= "/" . DEFAULT_NAMESPACE . ':' . $p;
    }
    return $xpath;
} 


sub _writeTempSvgFile {
    my ($self) = @_;

    my ($handle, $tempFileName) = tempfile(SUFFIX => ".svg");
    $self->{dom}->toFile($tempFileName);
    return $tempFileName;
}


sub _svgToPng {
    my ($self, $language, $svgFile) = @_;

    my $pngFile = $self->_makeFileName($language, "web", "png");
    my $cmd = "inkscape --without-gui --file=$svgFile";
    $cmd .= " --g-fatal-warnings";
    $cmd .= " --export-png=$pngFile --export-area-drawing --export-background=#ffffff";
    system($cmd) && croak("Could not run $cmd: $!");

    my $png = Image::PNG->new();
    $png->read($pngFile);
    $self->{height} = $png->height;
    $self->{width} = $png->width;
}


sub _makeFileName {
    my ($self, $language, $where, $ext) = @_;

    my $dir = "generated/$where/" . lc($language);
    File::Path::make_path($dir) or croak("Cannot mkdirs $dir: $!") unless(-d $dir);
    return "$dir/" . $self->_normalizedTitle($language) . ".$ext";
}


sub _makeUrl {
    my ($self, $language, $ext) = @_;

    return "https://$text{domain}{$language}/comics/" 
        . $self->_normalizedTitle($language) . ".$ext";
}        


sub _normalizedTitle {
    my ($self, $language) = @_;
    
    my $title = lc($self->{metaData}->{title}->{$language});
    croak "No title in $language" unless($title);
    $title =~ s/\s/-/g;
    $title =~ s/[^a-z0-9-_]//g;
    return $title;
}


=head2 exportHtml

Exports a HTML transcript of this Comic's texts per language.

The HTML page will be the same name as the generated PNG, with a .html
extension and will be placed next to it.

Parameters:

=over 4

    =item B<%languages> hash of short language name (e.g., en for English and
        de for German) to long language name.

=back

=cut

sub exportHtml {
    my ($self, %languages) = @_;

    foreach my $language (keys %languages) {
        next if $self->_notFor($language);

        $self->_exportLanguageHtml($language, %languages);
        $self->_writeSitemapXmlFragment($language);
    }
}


sub _exportLanguageHtml {
    my ($self, $language, %languages) = @_;

    # If the comic has no title for the given language, assume it does not
    # have language layers either and don't export a transcript.
    return if $self->_notFor($language);

    my $page = $self->_makeFileName($language, "web", "html");
    open my $F, ">", $page or croak "Cannot write $page: $!";
    $self->_exportHtml($F, $language, %languages);
    close $F or croak "Cannot close $page: $!";
}


sub _notFor {
    my ($self, $language) = @_;
    return !$self->{metaData}->{title}->{$language};
}


sub _exportHtml {
    my ($self, $F, $language, %languages) = @_;

    my %vars;
    my $title = $self->{metaData}->{title}->{$language};
    # SVG, being XML, needs to encode XML special characters, but does not do
    # HTML encoding. So first reverse the XML encoding, then apply any HTML
    # encoding.
    $vars{title} = encode_entities(decode_entities($title));
    $vars{pngFile} = $self->_makeFileName($language, "web", "png");
    $vars{modified} = $self->{modified};
    $vars{height} = $self->{height};
    $vars{width} = $self->{width};

    my $languageLinks = "";
    foreach my $l (sort(keys(%languages))) {
        next if ($l eq $language);
        
        my $title = $self->{metaData}->{title}->{$l};
        if ($title) {
            my $href = $self->_makeUrl($l, "png");
            my $alt = $text{langLink}{$l};
            my $linkText = uc($l);
            $languageLinks .= "<a href=\"$href\" alt=\"$alt\">$linkText</a> ";
        }
    }

    $vars{transcript} = "";
    foreach my $t ($self->_textsFor($language)) {
        $vars{transcript} .= "<p>" . encode_entities($t) . "</p>\n";
    }

    $vars{description} = encode_entities(
        $text{keywords}{$language} . ", " .
        join(", ", @{$self->{metaData}->{tags}->{$language}}));

    print $F $self->_templatize(_slurp($text{templateFile}{$language}), %vars);
}


sub _textsFor {
    my ($self, $language) = @_;

    $self->_findFrames();
    my @texts;
    foreach my $node (sort { $self->_textPosSort($a, $b) } $self->{xpath}->findnodes(_text($language))) {
        my XML::LibXML::Node $tspan = $node->firstChild();
        my $text = "";
        do {
            $text .= $tspan->textContent() . " ";
            $tspan = $tspan->nextSibling();
        }
        while ($tspan);
        $text =~ s/-\s+/-/mg;
        $text =~ s/ +/ /mg;
        $text =~ s/^\s+//mg;
        $text =~ s/\s+$//mg;
        
        if ($text eq "") {
            my $layer = $node->parentNode->{'inkscape:label'};
            croak "Empty text in $layer with ID $node->{id}\n";
        }
        push @texts, $text;
    }
    return @texts;
}


sub _findFrames {
    my ($self) = @_;

    # Find the frames in the comic. Remember the top of the frames.
    # Assume frames that have their top within a certain FRAME_TOLERANCE
    # distance from each other are meant to be at the same position.
    my @frameTops;
    my $frameXpath = _buildXpath('g[@inkscape:label="Rahmen"]', 'rect');
    foreach my $f ($self->{xpath}->findnodes($frameXpath)) {
        my $y = floor($f->getAttribute("y"));
        my $found = 0;
        foreach my $ff (@frameTops) {
            $found = 1 if ($ff + FRAME_TOLERANCE > $y && $ff - FRAME_TOLERANCE < $y);
        }
        push @frameTops, $y unless($found);
    }
    @{$self->{frameTops}} = sort @frameTops;
}


sub _textPosSort {
    my ($self, $a, $b) = @_;    
    # Inkscape coordinate system has 0/0 as bottom left corner
    my $ya = $self->_posToFrame(_transformed($a, "y"));
    my $yb = $self->_posToFrame(_transformed($b, "y"));
    return $ya <=> $yb || _transformed($a, "x") <=> _transformed($b, "x");
}


sub _transformed {
    my ($node, $attribute) = @_;

    my $transform = $node->getAttribute("transform");
    return $node->getAttribute($attribute) if (!$options{TRANSFORM} || !$transform);

    croak "Cannot handle multiple transformations" if ($transform !~ m/^(\w+)\(([^)]+)\)$/);
    my ($operation, $params) = ($1, $2);
    my ($a, $b, $c, $d, $e, $f);
    # Inkscape sources:
    # Operations in Inkscape's src/cvg/svg-affine.cpp
    # Actual matrix math in src/2geom/affine.cpp
    if ($operation eq "matrix") {
        ($a, $b, $c, $d, $e, $f) = split /,/, $params;
    }
    elsif ($operation eq "scale") {
        my ($sx, $sy) = split /,/, $params;
        ($a, $b, $c, $d, $e, $f) = ($sx, 0, 0, $sy, 0, 0);
    }
    else {
        croak "Unsupported operation $operation";
    }
    my $x = $node->getAttribute("x");
    my $y = $node->getAttribute("y");
    # http://www.w3.org/TR/SVG/coords.html#TransformMatrixDefined
    # a c e   x
    # b d f * y
    # 0 0 1   1
    # FIXME: Ignores inkscape:transform-center-x and inkscape:transform-center-y
    # attributes.
    return $a * $x + $c * $y if ($attribute eq "x");
    return $b * $x + $d * $y if ($attribute eq "y");
    croak "Unsupported attribute $attribute to transform";
}


sub _text {
    my $label = shift;
    return _buildXpath(
        "g[\@inkscape:label=\"$label\" or \@inkscape:label=\"Meta$label\"]/", 
        "text");
}


sub _posToFrame {
    my ($self, $y) = @_;
    for (my $i = 0; $i < @{$self->{frameTops}}; $i++) {
        return $i if ($y < @{$self->{frameTops}}[$i]);
    }
    return @{$self->{frameTops}};
}


sub _templatize {
    my ($self, $template, %vars) = @_;

    my %options = (
        STRICT => 1,
    );
    my $t = Template->new(%options) || 
        croak("Cannot construct template:: " . Template->error());
    my $output = "";
    $t->process(\$template, \%vars, \$output) || croak $t->error();
    if ($output =~ m/(\[%\S*)/m) {
        croak "Unresolved template marker $1";
    }
    return $output;
}


sub _writeSitemapXmlFragment {
    my ($self, $language) = @_;

    my $html = $self->_makeUrl($language, "html");
    my $path = "https://$text{domain}{$language}/";
    my $title = $self->{metaData}->{title}{$language};
    my $fragment = $self->_makeFileName($language, "tmp", "xml");

    _writeFile($fragment, <<XML);
<url>
<loc>$html</loc>
<image:image>
<image:loc>${path}comics/$self->{pngFile}</image:loc>
<image:title>$title</image:title>
<image:license>$path$text{licensePage}{$language}</image:license>
</image:image>
<lastmod>$self->{modified}</lastmod>
</url>
XML
}


sub _writeFile {
    my ($fileName, $contents) = @_;

    open my $F, ">", $fileName or croak "Cannot write $fileName: $!";
    print $F $contents;
    close $F or croak "Cannot close $fileName: $!";
}


=head2 countsOfIn

Returns the counts of all x in the given language.
This can be used for a tag cloud.

Parameters:

=over 4

    =item B<$what> what counts to get, e.g., "tags" or "people".

    =item B<$language> for what language, e.g., "English".

=back

=cut

sub countsOfIn {
    my ($what, $language) = @_;
    return $counts{$what}{$language};
}


1;


=head1 BUGS AND LIMITATIONS

Works only with Inkscape files.

No bugs have been reported.

Please report any bugs or feature requests to C<< <robert.wenner@posteo.de> >>


=head1 AUTHOR

Robert Wenner  C<< <robert.wenner@posteo.de> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, Robert Wenner C<< <robert.wenner@posteo.de> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


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
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
