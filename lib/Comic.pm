package Comic;

use strict;
use warnings;

use base qw(Exporter);
use POSIX;
use Carp;
use File::Path qw(make_path);
use File::Basename;
use File::Temp qw/tempfile/;
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use XML::LibXML;
use XML::LibXML::XPathContext;
use JSON;

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
};

our %options = (
    # Whether to transform SVG coordinates if the transform atttribute is used.
    # This may be needed for fancy texts (tilted or on a path) so that the new
    # translated coordinates can be sorted as expected for the comic's transcript.
    # However, it may be easier to just add invisible frames to force a text
    # order in the comic.
    TRANSFORM => 1,
);

my %people;
my %tags;
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
}


sub _slurp {
    my ($file) = @_;

    open my $F, "<", $file or croak "Cannot open $file: $!";
    local $/ = undef;
    my $contents = <$F>;
    close $F or croak "Cannot close $file: $!";
    return $contents;
}


=head2 exportPng

Exports PNGs for all languages found in this Comic.

The png file will be the same name as the input SVG, with a PNG extension.
It will be placed in F<generated/$lang/> where $lang is a 2 letter language
shortcut.

Parameters:

=over 4

    =item B<%languages> hash of short language name (e.g., en for English and
        de for German) to long language name.

=back

=cut

sub exportPng {
    my ($self, %languages) = @_;

    foreach my $lang (keys(%languages)) {
        $self->_sanityChecks($languages{$lang});
        $self->_count("tags", $languages{$lang}, \%tags);
        $self->_count("who", $languages{$lang}, \%people);
        $self->_flipLanguageLayers($lang, %languages);
        $self->_svgToPng($languages{$lang}, $self->_writeTempSvgFile());
    }
}


sub _sanityChecks {
    my ($self, $lang) = @_;

    my $title = $self->{metaData}->{title}->{$lang};
    my $key = lc("$lang\n$title");
    $key =~ s/^\s+//;
    $key =~ s/\s+$//;
    $key =~ s/\s+/ /g;
    if (defined($titles{$key})) {
        if ($titles{$key} ne $self->{file}) {
            croak("Duplicated $lang title '$title' in $titles{$key} and $self->{file}");
        }
    }
    $titles{$key} = $self->{file};
}


sub _count {
    my ($self, $what, $lang, $counts) = @_;

    foreach my $tag (@{$self->{metaData}->{$what}->{$lang}}) {
        croak("No $lang tag") unless(defined($tag));
        croak("Empty $lang tag") if ($tag =~ m/^\s*$/);
        $$counts{$tag}++;
    }
}


sub _flipLanguageLayers {
    my ($self, $lang, %languages) = @_;

    # Hide all but current language layers
    my $hadLang = 0;
    my $allLayers = _buildXpath('g[@inkscape:groupmode="layer"]');
    foreach my $layer ($self->{xpath}->findnodes($allLayers)) {
        my $label = $layer->{"inkscape:label"};
        foreach my $otherLang (keys(%languages)) {
            # Turn off all meta layers and all other languages
            if ($label =~ m/$otherLang$/ || $label =~ m/^Meta/) {
                $layer->{"style"} = "display:none";
            }
        }
        # Make sure the right language layer is visible
        if ($label =~ m/$lang$/ && $label !~ m/Meta/) {
            $layer->{"style"} = "display:inline";
            $hadLang = 1;
        }
    }
    unless ($hadLang) {
        if ($self->{file} =~ m@/([a-z]{2,3})/[^/]+.svg$@) {
            return if ($1 ne $languages{$lang} || $1 eq "div");
        }
        croak "No $lang layer";
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

    my $dir = $self->_makeComicsPath($language);
    my $png = $dir . basename($self->{file}, ".svg") . ".png";
    my $cmd = "inkscape --without-gui --file=$svgFile";
    $cmd .= " --g-fatal-warnings";
    $cmd .= " --export-png=$png --export-area-drawing --export-background=#ffffff";
    system($cmd) && croak("Could not run $cmd: $!");
}


sub _makeComicsPath {
    my ($self, $language) = @_;

    my $pages = "generated/comics/";
    my $dir = "$pages/$language/";
    make_path($dir) or croak("Cannot mkdirs $dir: $!") unless(-d $dir);
    return $dir;
}


=head2 exportHtml

Exports a HTML transcript of this Comic's texts per language.

The HTML transcript file will be the same name as the input SVG, with a
.html extension. It will be placed in F<generated/$lang/> where $lang is a 2
letter language shortcut.

Parameters:

=over 4

    =item B<%languages> hash of short language name (e.g., en for English and
        de for German) to long language name.

=back

=cut

sub exportHtml {
    my ($self, %languages) = @_;

    foreach my $lang (keys(%languages)) {
        $self->_exportLanguageHtml($languages{$lang}, $lang);
    }
}


sub _exportLanguageHtml {
    my ($self, $lang, $language) = @_;

    my $dir = $self->_makeComicsPath($lang);
    my $page = $dir . basename($self->{file}, ".svg") . ".html";
    open my $F, ">", $page or croak "Cannot write $page: $!";
    foreach my $t ($self->_textsFor($language)) {
        print $F "<p>$t</p>\n\n";
    }
    print $F "\n";
    close $F or croak "Cannot close $page: $!";
}


sub _textsFor {
    my ($self, $lang) = @_;

    $self->_findFrames();
    my @texts;
    foreach my $node (sort { $self->_textPosSort($a, $b) } $self->{xpath}->findnodes(_text($lang))) {
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


=head2 people

Prints how often people's names were seen in the people tag in all comics
processed. This can be used for a tag cloud.

=cut

sub people {
    _printSortedHash("People", %people);
}


=head2 tags 

Prints how often tags were seen in the people tag in all comics processed.
This can be used for a tag cloud.

=cut

sub tags {
    _printSortedHash("Tags", %tags);
}


sub _printSortedHash {
    my ($heading, %hash) = @_;

    print "$heading:\n";
    foreach my $p (sort { $hash{$b} cmp $hash{$a} } keys(%hash)) {
        print "\t$p: $hash{$p}\n";
    }
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
