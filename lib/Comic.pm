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
use Image::ExifTool qw(:Public);
use Template;
use SVG;


use version; our $VERSION = qv('0.0.2');

=for stopwords Inkscape inkscape html SVG svg PNG png Wenner MERCHANTABILITY perlartistic


=head1 NAME

Comic - Converts SVG comics to png by language and creates HTML pages.


=head1 VERSION

This document refers to version 0.0.2.


=head1 SYNOPSIS

    use Comic;

    my @languages = (
        "Deutsch",
        "English"
    );

    foreach my $file (@ARGV) {
        my $c = Comic->new($file);
        $c->export_png(@languages);
        $c->export_html(@languages);
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
# What date to use for sorting unpublished comics.
Readonly our $UNPUBLISHED => '3000-01-01';
# Expected frame thickness.
Readonly our $FRAME_WIDTH => 1.25;
# Allowed deviation from expected frame width.
Readonly our $FRAME_WIDTH_DEVIATION => 0.25;

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
    comicTemplateFile => {
        'English' => 'web/english/comic-page.templ',
        'Deutsch' => 'web/deutsch/comic-page.templ',
    },
    archiveTemplateFile => {
        'English' => 'web/english/archive.templ',
        'Deutsch' => 'web/deutsch/archiv.templ',
    },
    backlogTemplateFile => {
        'English' => 'web/english/backlog.templ',
        'Deutsch' => 'web/deutsch/backlog.templ',
    },
    archivePage => {
        'English' => 'archive.html',
        'Deutsch' => 'archiv.html',
    },
    archiveTitle => {
        'English' => 'The beercomics.com archive',
        'Deutsch' => 'Das Biercomics-Archiv',
    },
    backlogPage => {
        'English' => 'backlog.html',
        'Deutsch' => 'backlog.html',
    },
    imprintPage => {
        'English' => 'imprint.html',
        'Deutsch' => 'impressum.html',
    },
    imprintPageAbsolute => {
        'English' => 'https://beercomics.com/imprint.html',
        'Deutsch' => 'https://biercomics.de/impressum.html',
    },
    logo => {
        'English' => 'beercomics-logo.png',
        'Deutsch' => 'biercomics-logo.png',
    },
    ccbutton => {
        'English' => 'cc.png',
        'Deutsch' => 'cc.png',
    },
    sizeMapTemplateFile => {
        'English' => 'web/english/sizemap.templ',
        'Deutsch' => 'web/deutsch/sizemap.templ',
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
    eval {
        $self->{meta_data} = from_json($meta_data);
    } or croak "$file: Error in JSON for: $EVAL_ERROR";
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

    =item B<@languages> language names (e.g., "English"). The language name
        must be used in the Inkscape layer names and the JSON meta data.

        This code will only work on the languages passed, even if additional
        languages are present in the SVG. Specifying a language that the SVG
        does not have is fine, you just don't get any output (png,
        transcript) for it.

=back

=cut

sub export_png {
    my ($self, @languages) = @ARG;

    foreach my $language (@languages) {
        next if $self->_not_for($language);

        $counts{'comics'}{$language}++;

        my $to = $self->_not_yet_published() ? 'tmp/backlog' : 'web/comics';
        my $png_file = $self->_make_file_name($language, $to, 'png');
        $self->{pngFile}{$language} = basename($png_file);

        unless (_up_to_date($self->{file}, $png_file)) {
            $self->_check_title($language);
            $self->_check_dont_publish($language);
            $self->_check_frames();
            $self->_check_tags('tags', $language);
            $self->_check_tags('people', $language);
            $self->_check_transcript($language);

            $self->_flip_language_layers($language, @languages);
            $self->_svg_to_png($language, $self->_write_temp_svg_file(), $png_file);
        }
        $self->_get_png_info($png_file);
    }
    $self->_count_tags();
    return;
}


sub _up_to_date {
    my ($svg_file, $png_file) = @_;

    my $up_to_date = 0;
    if (_exists($png_file)) {
        my $svg_mod = _mtime($svg_file);
        my $png_mod = _mtime($png_file);
        $up_to_date = $png_mod > $svg_mod;
    }
    return $up_to_date;
}


sub _exists {
    return -r shift;
}


sub _check_title {
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

    $self->_check_json('', $self->{meta_data});

    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $all_layers = _build_xpath('g[@inkscape:groupmode="layer"]');
    ## use critic
    foreach my $layer ($self->{xpath}->findnodes($all_layers)) {
        my $text = $layer->textContent();
        my $label = $layer->{'inkscape:label'};
        if ($text =~ m/(\b$DONT_PUBLISH\b[^\n\r]*)/m) {
            croak "In $self->{file} in layer $label: $1";
        }
    }
    return;
}


sub _check_json {
    my ($self, $where, $what) = @ARG;

    if (ref($what) eq 'HASH') {
        foreach my $key (keys %{$what}) {
            $self->_check_json("$where > $key", $what->{$key});
        }
    }
    elsif (ref($what) eq 'ARRAY') {
        for my $i (0 .. $#{$what}) {
            $self->_check_json($where . '[' . ($i + 1) . ']', $what->[$i]);
        }
    }
    elsif ($what =~ m/$DONT_PUBLISH/m) {
        croak "In $self->{file} in JSON$where: $what";
    }
    return;
}


sub _check_frames {
    my ($self) = @ARG;

    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $frame_xpath = _build_xpath('g[@inkscape:label="Rahmen"]', 'rect');
    ## use critic
    foreach my $f ($self->{xpath}->findnodes($frame_xpath)) {
        my $style = $f->getAttribute('style');
        if ($style =~ m{;stroke-width:([^;]+);}) {
            my $width = $1;
            if ($width < $FRAME_WIDTH - $FRAME_WIDTH_DEVIATION) {
                croak "Frame too narrow ($width) in $self->{file}";
            }
            if ($width > $FRAME_WIDTH + $FRAME_WIDTH_DEVIATION) {
                croak "Frame too wide ($width) in $self->{file}";
            }
        }
        else {
            croak "Cannot find width in $style from $self->{file}";
        }
    }
    return;
}


sub _check_tags {
    my ($self, $what, $language) = @ARG;

    foreach my $tag (@{$self->{meta_data}->{$what}->{$language}}) {
        croak("No $language $what in $self->{file}") unless(defined $tag);
        croak("Empty $language $what in $self->{file}") if ($tag =~ m/^\s*$/);
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


sub _check_transcript {
    my ($self, $language) = @_;

    my $previous = '';
    foreach my $t ($self->_texts_for($language)) {
        if (_both_names($previous, $t)) {
            croak "$language: '$t' after '$previous'";
        }
        $previous = $t;
    }
    return;
}


sub _both_names {
    my ($a, $b) = @_;
    if ($a =~ m/:$/ && $b =~ m/:$/) {
        return 1;
    }
    $a =~ s/:$//;
    $b =~ s/:$//;
    if (lc $a eq lc $b && $a ne '') {
        return 1;
    }
    return 0;
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
        croak "No $language layer in $self->{file}";
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
    my ($self, $language, $svg_file, $png_file) = @ARG;

    my $export_cmd = "inkscape --without-gui --file=$svg_file" .
        ' --g-fatal-warnings' .
        " --export-png=$png_file --export-area-drawing --export-background=#ffffff";
    system($export_cmd) && croak("Could not export: $export_cmd: $OS_ERROR");

    my $tool = Image::ExifTool->new();
    _set_png_meta($tool, 'Title', $self->{meta}->{title}->{$language});
    _set_png_meta($tool, 'Artist', 'Robert Wenner');
    my $transcript = '';
    foreach my $t ($self->_texts_for($language)) {
        $transcript .= ' ' unless ($transcript eq '');
        $transcript .=  $t;
    }
    _set_png_meta($tool, 'Description', $transcript);
    _set_png_meta($tool, 'CreationTime', $self->{modified});
    _set_png_meta($tool, 'Copyright', 'CC BY-NC-SA 4.0');
    _set_png_meta($tool, 'URL', $self->_make_url($language, 'png'));
    my $rc = $tool->WriteInfo($png_file);
    if ($rc != 1) {
        croak("$svg_file: cannot write info: " . tool->GetValue('Error'));
    }

    my $shrink_cmd = "optipng --quiet $png_file";
    system($shrink_cmd) && croak("Could not shrink: $shrink_cmd: $OS_ERROR");

    return;
}


sub _set_png_meta {
    my ($tool, $name, $value) = @ARG;

    my ($count_set, $error) = $tool->SetNewValue($name, $value);
    croak("Cannot set $name: $error") if ($error);
    return;
}


sub _get_png_info {
    my ($self, $png_file) = @_;

    my $tool = Image::ExifTool->new();
    my $info = $tool->ImageInfo($png_file);

    $self->{height} = ${$info}{'ImageHeight'};
    $self->{width} = ${$info}{'ImageWidth'};
    return;
}


sub _make_file_name {
    my ($self, $language, $where, $ext) = @ARG;

    return _make_dir($language, $where) . q{/} . $self->_normalized_title($language) . ".$ext";
}


sub _make_dir {
    my ($language, $where) = @ARG;
    my $dir = 'generated/' . lc $language . "/$where";
    File::Path::make_path($dir) or croak("Cannot mkdirs $dir: $OS_ERROR") unless(-d $dir);
    return $dir;
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

    =item B<@languages> language names to export.

=back

=cut

sub export_all_html {
    my (@languages) = @ARG;

    foreach my $c (@comics) {
        foreach my $language (@languages) {
            next if $c->_not_for($language);
            my $name = $c->_make_file_name($language, 'web/comics', 'html');
            $c->{htmlFile}{$language} = basename($name);
        }
    }

    my @sorted = sort _compare @comics;
    # Would be nice to do this incrementally...
    foreach my $i (0 .. @sorted - 1) {
        my $comic = $sorted[$i];
        foreach my $language (@languages) {
            next if ($comic->_not_for($language));

            my $first_comic = _find_next($language, $i, \@sorted, [0 .. $i - 1]);
            $comic->{'first'}{$language} = $first_comic ? $first_comic->{htmlFile}{$language} : 0;
            my $prev_comic = _find_next($language, $i, \@sorted, [reverse 0 .. $i - 1]);
            $comic->{'prev'}{$language} = $prev_comic ? $prev_comic->{htmlFile}{$language} : 0;
            my $next_comic = _find_next($language, $i, \@sorted, [$i + 1 .. @sorted - 1]);
            $comic->{'next'}{$language} = $next_comic ? $next_comic->{htmlFile}{$language} : 0;
            my $last_comic = _find_next($language, $i, \@sorted, [reverse $i + 1 .. @sorted - 1]);
            $comic->{'last'}{$language} = $last_comic ? $last_comic->{htmlFile}{$language} : 0;

            my $to = $comic->_not_yet_published() ? 'tmp/backlog' : 'web/comics';
            $comic->_export_language_html($to, $language);
            $comic->_write_sitemap_xml_fragment($language);
        }
    }
    return;
}


sub _not_yet_published {
    my ($self) = @_;

    Readonly my $DAYS_PER_WEEK => 7;
    Readonly my $FRIDAY => 5;

    my $till = _now();
    my $dow = $till->day_of_week();
    if ($dow != $FRIDAY) {
        # On Friday, just do comics up until today. On any other day, also include
        # the comic for next Friday.
        # That way, when the web site update script runs on 00:00:02 on Friday
        # night, it will only include comics up to today's comic, but when I run
        # the script on any other day of the week it will already include the
        # next comic in the queue for previewing.
        $till->add(days => $DAYS_PER_WEEK);
        # Adding 7 week days (going one week further) makes sure next Friday is
        # in the valid dates range.
    }
    my $published = $self->{meta_data}->{published}->{when} || $UNPUBLISHED;
    return ($published cmp $till->ymd) > 0;
}


sub _now {
    return DateTime->now;
}


sub _find_next {
    my ($language, $pos, $comics, $nums) = @_;

    foreach my $i (@{$nums}) {
        next if (@{$comics}[$i]->_not_for($language));
        if (@{$comics}[$i]->_not_yet_published() == @{$comics}[$pos]->_not_yet_published()) {
            return @{$comics}[$i];
        }

    }
    return 0;
}


sub _export_language_html {
    my ($self, $to, $language) = @ARG;

    my $page = $self->_make_file_name($language, $to, 'html');
    return _write_file($page, $self->_do_export_html($language));
}


sub _not_for {
    my ($self, @args) = @ARG;
    # Cannot just use !$self->_is_for cause Perl's weird truthiness can turn
    # the result into an empty text, and then tests trip over that.
    return $self->_is_for(@args) == 1 ? 0 : 1;
}


sub _is_for {
    my ($self, $language) = @ARG;
    return defined($self->{meta_data}->{title}->{$language}) ? 1 : 0;
}


sub _do_export_html {
    my ($self, $language) = @ARG;

    my %vars;
    my $title = $self->{meta_data}->{title}->{$language};
    # SVG, being XML, needs to encode XML special characters, but does not do
    # HTML encoding. So first reverse the XML encoding, then apply any HTML
    # encoding.
    $vars{title} = encode_entities(decode_entities($title));
    $vars{png_file} = basename($self->_make_file_name($language, 'web/comics', 'png'));
    $vars{modified} = $self->{modified};
    $vars{height} = $self->{height};
    $vars{width} = $self->{width};
    $vars{'url'} = $self->_make_url($language, 'html');
    $vars{'first'} = $self->{'first'}{$language};
    $vars{'prev'} = $self->{'prev'}{$language};
    $vars{'next'} = $self->{'next'}{$language};
    $vars{'last'} = $self->{'last'}{$language};

    # By default, use normal path with comics in comics/
    my $path = '../';
    # Adjust the path for backlog comics.
    $path = '../../web/' if ($self->_not_yet_published());
    # Adjust the path for top-level index.html
    if ($self->{isLatestPublished}) {
        $path = '';
        $vars{png_file} = 'comics/' . basename($vars{png_file});
        $vars{'first'} = 'comics/' . $self->{'first'}{$language};
        $vars{'prev'} = 'comics/' . $self->{'prev'}{$language};
    }
    $vars{'archive'} = "${path}$text{archivePage}{$language}";
    $vars{'imprint'} = "${path}$text{imprintPage}{$language}";
    $vars{'imprintCC'} = "$text{imprintPageAbsolute}{$language}";
    $vars{'favicon'} = "${path}favicon.png";
    $vars{'stylesheet'} = "${path}styles.css";
    $vars{'logo'} = "${path}$text{logo}{$language}";
    $vars{'ccbutton'} = "${path}$text{ccbutton}{$language}";
    $vars{'contrib'} = $self->{meta_data}->{contrib} || 0;

    $vars{transcript} = '';
    foreach my $t ($self->_texts_for($language)) {
        $vars{transcript} .= '<p>' . encode_entities($t) . "</p>\n";
    }

    my $tags = '';
    foreach my $t (@{$self->{meta_data}->{tags}->{$language}}) {
        $tags .= ', ' unless ($tags eq '');
        $tags .= $t;
    }
    $vars{description} = encode_entities($text{keywords}{$language} . ', ' . $tags);
    return _templatize(_slurp($text{comicTemplateFile}{$language}), %vars)
        or croak "Error writing HTML: $OS_ERROR";
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
            croak "Empty text in $layer with ID $node->{id} in $self->{file}";
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
    if ($transform !~ m/^(\w+)\(([^)]+)\)$/) {
        croak "Cannot handle multiple transformations in $self->{file}";
    }
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
        croak "Unsupported operation $operation in $self->{file}";
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
    croak "Unsupported attribute $attribute to transform in $self->{file}";
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
    my ($template, %vars) = @ARG;

    my %options = (
        STRICT => 1,
    );
    my $t = Template->new(%options) ||
        croak('Cannot construct template: ' . Template->error());
    my $output = '';
    $t->process(\$template, \%vars, \$output) || croak $t->error() . "\n";
    if ($output =~ m/\[%/mg || $output =~ m/%\]/mg) {
        croak 'Unresolved template marker';
    }
    return $output;
}


sub _write_sitemap_xml_fragment {
    my ($self, $language) = @ARG;

    return if ($self->_not_for($language) || $self->_not_yet_published());

    my $html = $self->_make_url($language, 'html');
    my $path = "https://$text{domain}{$language}";

    my $fragment = $self->_make_file_name($language, 'tmp/sitemap', 'xml');
    _write_file($fragment, <<"XML");
<url>
<loc>$html</loc>
<image:image>
<image:loc>${path}/comics/$self->{pngFile}{$language}</image:loc>
<image:title>$self->{meta_data}->{title}{$language}</image:title>
<image:license>$path/$text{imprintPage}{$language}</image:license>
</image:image>
<lastmod>$self->{modified}</lastmod>
</url>
XML
    return;
}


sub _write_file {
    my ($file_name, $contents) = @ARG;

    open my $F, '>', $file_name or croak "Cannot open $file_name: $OS_ERROR";
    print {$F} $contents or croak "Cannot write to $file_name: $OS_ERROR";
    close $F or croak "Cannot close $file_name: $OS_ERROR";
    return;
}


=head2 export_archive

Generates a single HTML page with all comics in chronological order.

The output file will be in generated/web/language/archivePage.html.

Parameters:

=over 4

    =item B<$archive_templates> reference to a hash of long language name to
    the archive template file for that language.

    =item B<$backlog_templates> reference to a hash of long language name to
    backlog template file for that language.

=back

=cut

sub export_archive {
    my ($archive_templates, $backlog_templates) = @ARG;

    foreach my $c (@comics) {
        foreach my $language (keys %{$archive_templates}) {
            next unless ($c->_is_for($language));

            my $name;
            my $dir;
            if ($c->_not_yet_published()) {
                $name = $c->_make_file_name($language, 'tmp/backlog', 'html');
                $dir = 'backlog/';
            }
            else {
                $name = $c->_make_file_name($language, 'web/comics', 'html');
                $dir = 'comics/';
            }
            $c->{href}{$language} = $dir . basename($name);
        }
    }

    foreach my $language (keys %{$archive_templates}) {
        my @sorted = (sort _compare grep { _archive_filter($_, $language) } @comics);
        next if (@sorted == 0);
        my $last_pub = $sorted[-1];
        $last_pub->{isLatestPublished} = 1;
        my $page = _make_dir($language, 'web') . '/index.html';
        _write_file($page, $last_pub->_do_export_html($language));
    }

    _do_export_archive('archive', 'web', '', \&_archive_filter, %{$archive_templates});
    _do_export_archive('backlog', 'tmp', '../web/', \&_backlog_filter, %{$backlog_templates});
    return;
}


sub _archive_filter {
    my ($comic, $language) = @ARG;
    return !$comic->_not_yet_published() && $comic->_is_for($language);
}


sub _backlog_filter {
    my ($comic, $language) = @ARG;
    return $comic->_not_yet_published() && $comic->_is_for($language);
}


sub _do_export_archive {
    my ($what, $dir, $url, $filter, %templates) = @ARG;

    foreach my $language (keys %templates) {
        my @filtered = sort _compare grep { $filter->($_, $language) } @comics;
        my $hrsn = "${what}Page";
        my $page = 'generated/' . lc($language) . "/$dir/$text{$hrsn}{$language}";

        if (!@filtered) {
            _write_file($page, "<p>No comics in $what.</p>");
            next;
        }

        my %vars;
        $vars{'title'} = $text{archiveTitle}{$language};
        $vars{'url'} = $text{archivePage}{$language};
        $vars{'comics'} = \@filtered;
        $vars{'modified'} = $filtered[-1]->{modified};
        $vars{'notFor'} = \&_not_for;
        $vars{'imprint'} = "${url}$text{imprintPage}{$language}";
        $vars{'imprintCC'} = "$text{imprintPageAbsolute}{$language}";
        $vars{'logo'} = "${url}$text{logo}{$language}";
        $vars{'favicon'} = "${url}favicon.png";
        $vars{'stylesheet'} = "${url}styles.css";
        $vars{'archive'} = "${url}$text{archivePage}{$language}";
        $vars{'ccbutton'} = "${url}$text{ccbutton}{$language}";
        $vars{'sizemap'} = 'sizemap.html';

        my $t = _slurp($templates{$language});
        _write_file($page, _templatize($t, %vars));
    }
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
    my $pub_a = $_[0]->{meta_data}->{published}{when} || $UNPUBLISHED;
    my $pub_b = $_[1]->{meta_data}->{published}{when} || $UNPUBLISHED;
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


=head2 size_map

Writes an SVG size map of all comics for comparing sizes.

Parameters:

=over 4

    =item B<@languages> for what languages.

=back

=cut

sub size_map {
    my (@languages) = @ARG;

    my %aggregate;
    foreach my $comic (@comics) {
        foreach my $language (@languages) {
            next unless ($comic->_is_for($language));
            foreach my $dim (qw(height width)) {
                if (!defined($aggregate{$language}{$dim}{'min'}) ||
                    $aggregate{$language}{$dim}{'min'} > $comic->{$dim}) {
                    $aggregate{$language}{$dim}{'min'} = $comic->{$dim};
                }
                if (!defined($aggregate{$language}{$dim}{'max'}) ||
                    $aggregate{$language}{$dim}{'max'} < $comic->{$dim}) {
                    $aggregate{$language}{$dim}{'max'} = $comic->{$dim};
                }
                $aggregate{$language}{$dim}{'avg'} += $comic->{$dim};
                $aggregate{$language}{$dim}{'cnt'}++;
            }
        }
    }

    foreach my $language (@languages) {
        foreach my $dim (qw(height width)) {
            if (($aggregate{$language}{$dim}{'cnt'} || 0) == 0) {
                $aggregate{$language}{$dim}{avg} = 'n/a';
            }
            else {
                $aggregate{$language}{$dim}{avg} /= $aggregate{$language}{$dim}{'cnt'};
            }
        }
    }

    Readonly my $SCALE_BY => 0.3;
    foreach my $language (@languages) {
        my $svg = SVG->new(
            width => $aggregate{$language}{width}{'max'} * $SCALE_BY,
            height => $aggregate{$language}{height}{'max'} * $SCALE_BY,
            -printerror => 1,
            -raiseerror => 1);
        foreach my $comic (@comics) {
            my $color = 'green';
            $color = 'blue' if ($comic->_not_yet_published());
            $svg->rectangle(x => 0, y => 0,
                width => $comic->{width} * $SCALE_BY,
                height => $comic->{height} * $SCALE_BY,
                id => basename("$comic->{file}"),
                style => {
                    'fill-opacity' => 0,
                    'stroke-width' => '3',
                    'stroke' => "$color",
                });
        }

        my %vars;
        foreach my $agg (qw(min max avg)) {
            foreach my $dim (qw(width height)) {
                $vars{"$agg$dim"} = $aggregate{$language}{$dim}{$agg} || 'n/a';
            }
        }
        $vars{'title'} = 'Sizemap';
        $vars{'url'} = 'backlog.html';
        $vars{'height'} = $aggregate{$language}{height}{'max'} * $SCALE_BY;
        $vars{'width'} = $aggregate{$language}{width}{'max'} * $SCALE_BY;
        $vars{'logo'} = "../web/$text{logo}{$language}";
        $vars{'imprint'} = "../web/$text{imprintPage}{$language}";
        $vars{'imprintCC'} = "$text{imprintPageAbsolute}{$language}";
        $vars{'ccbutton'} = "../web/$text{ccbutton}{$language}";
        $vars{'favicon'} = '../web/favicon.png';
        $vars{'stylesheet'} = '../web/styles.css';
        $vars{'archive'} = "../web/$text{archivePage}{$language}";
        $vars{'backlog'} = 'backlog.html';
        $vars{'comics_by_width'} = [sort _by_width @comics];
        $vars{'comics_by_height'} = [sort _by_height @comics];
        $vars{'notFor'} = \&_not_for;

        $vars{svg} = $svg->xmlify();
        # Remove XML declaration and doctype; Firefox marks them red in the source
        # view of the page.
        $vars{svg} =~ s/<\?xml[^>]+>\n//;
        $vars{svg} =~ s/<!DOCTYPE[^>]+>\n//;

        _write_file('generated/' . lc($language) . '/tmp/sizemap.html',
            _templatize(_slurp($text{sizeMapTemplateFile}{$language}), %vars));
    }
    return;
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
