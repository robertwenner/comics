package Comic;

use strict;
use warnings;

use Readonly;
use English '-no_match_vars';
use utf8;
use Locales unicode => 1;
use base qw(Exporter);
use POSIX;
use Carp;
use autodie;
use String::Util 'trim';
use DateTime;
use DateTime::Format::ISO8601;
use File::Path qw(make_path);
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

=for stopwords Inkscape inkscape html SVG svg PNG png Wenner MERCHANTABILITY perlartistic MetaEnglish RSS


=head1 NAME

Comic - Converts SVG comics to png by language and creates HTML pages.


=head1 VERSION

This document refers to version 0.0.2.


=head1 SYNOPSIS

    use Comic;

    foreach my $file (@ARGV) {
        my $c = Comic->new($file);
        $c->export_png();
    }
    Comic::export_all_html();


=head1 DESCRIPTION

From on an Inkscape SVG file, exports language layers to create per language
PNG files. Creates a transcript per language for search engines.

=cut


# XPath default namespace name.
Readonly our $DEFAULT_NAMESPACE => 'defNs';
# How to mark a comic as not publishable, so that the converter can flag it.
Readonly our $DONT_PUBLISH => 'DONT_PUBLISH';
# What date to use for sorting unpublished comics.
Readonly our $UNPUBLISHED => '3000-01-01';
# Expected frame thickness in pixels.
Readonly our $FRAME_WIDTH => 1.25;
# Tolerance in pixels when looking for frames.
Readonly our $FRAME_TOLERANCE => 1.0;
# Allowed deviation from expected frame width in pixels.
Readonly our $FRAME_WIDTH_DEVIATION => 0.25;
# After how many pixels a frame is assumed to be in the next row.
Readonly our $FRAME_ROW_HEIGHT => 50;
# How many pixels space there should be between frames (both x and y).
Readonly our $FRAME_SPACING => 10;
# Maximum tolerance in pixels for distance between frames.
Readonly our $FRAME_SPACING_TOLERANCE => 2.0;
# Whether to transform SVG coordinates if the transform atttribute is used.
# This may be needed for fancy texts (tilted or on a path) so that the new
# translated coordinates can be sorted as expected for the comic's transcript.
# However, it may be easier to just add invisible frames to force a text
# order in the comic.
Readonly our $TRANSFORM => 1;


my %text = (
    domain => { # can we get rid off this? No, needed to put the URL in the PNG.
        'English' => 'beercomics.com',
        'Deutsch' => 'biercomics.de',
    },
    comicTemplateFile => {
        'English' => 'templates/english/comic-page.templ',
        'Deutsch' => 'templates/deutsch/comic-page.templ',
    },
    archiveTemplateFile => {
        'English' => 'templates/english/archive.templ',
        'Deutsch' => 'templates/deutsch/archiv.templ',
    },
    archivePage => {
        'English' => 'archive.html',
        'Deutsch' => 'archiv.html',
    },
    archiveTitle => {
        'English' => 'The beercomics.com archive',
        'Deutsch' => 'Das Biercomics-Archiv',
    },
    backlogTemplateFile => 'templates/backlog.templ',
    backlogPage => 'backlog.html',
    sitemapXmlTemplateFile => {
        'English' => 'templates/english/sitemap-xml.templ',
        'Deutsch' => 'templates/deutsch/sitemap-xml.templ',
    },
    sitemapXmlTo => {
        'English' => 'generated/english/web/sitemap.xml',
        'Deutsch' => 'generated/deutsch/web/sitemap.xml',
    },
);


my %counts;
my %titles;
my %language_code_cache;
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

    $self->{srcFile} = $file;
    $self->{dom} = XML::LibXML->load_xml(string => _slurp($file));
    $self->{xpath} = XML::LibXML::XPathContext->new($self->{dom});
    $self->{xpath}->registerNs($DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $meta_xpath = _build_xpath('metadata/rdf:RDF/cc:Work/dc:description/text()');
    my $meta_data = join ' ', $self->{xpath}->findnodes($meta_xpath);
    eval {
        $self->{meta_data} = from_json($meta_data);
    } or $self->_croak("Error in JSON for: $EVAL_ERROR");

    $self->{modified} = DateTime->from_epoch(epoch => _mtime($file))->ymd;
    my $pub = trim($self->{meta_data}->{published}->{when});
    if ($pub) {
        my $dt = DateTime::Format::ISO8601->parse_datetime($pub);
        $dt->set_time_zone(_get_tz());
        $self->{rfc822pubDate} = $dt->strftime('%a, %d %b %Y %H:%M:%S %z');
    }

    foreach my $language ($self->_languages()) {
        my $name = $self->_make_file_name($language, 'web/comics', 'html');
        $self->{htmlFile}{$language} = basename($name);
    }

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


sub _get_tz {
    return strftime '%z', localtime;
}


=head2 export_png

Exports PNGs for all languages with meta data in the graphic.

The png file will be the lower case title of the comic, limited to ASCII
only characters. It will be placed in F<generated/web/$language/>.

Inkscape files must have meta data matching layer names, e.g., "English" in
the meta data and an "English" layer and an "MetaEnglish" layer

=cut

sub export_png {
    my ($self) = @ARG;

    foreach my $language ($self->_languages()) {
        $counts{'comics'}{$language}++;

        $self->_check($language);

        my $png_file;
        if ($self->_not_yet_published()) {
            $png_file = _make_dir('backlog/') . $self->_normalized_title($language) . '.png';
        }
        else {
            $png_file = $self->_make_file_name($language, '/web/comics', 'png');
        }
        $self->{pngFile}{$language} = basename($png_file);

        unless (_up_to_date($self->{srcFile}, $png_file)) {
            $self->_flip_language_layers($language);
            $self->_svg_to_png($language, $self->_write_temp_svg_file($language), $png_file);
        }
        $self->_get_png_info($png_file);
    }
    $self->_count_tags();
    return;
}


sub _check {
    my ($self, $language) = @_;

    $self->_check_title($language);
    $self->_check_date();
    $self->_check_dont_publish($language);
    $self->_check_frames();
    $self->_check_tags('tags', $language);
    $self->_check_tags('people', $language);
    $self->_check_transcript($language);
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
    my $key = trim(lc "$language\n$title");
    $key =~ s/\s+/ /g;
    if (defined $titles{$key}) {
        if ($titles{$key} ne $self->{srcFile}) {
            $self->_croak("Duplicated $language title '$title' in $titles{$key}");
        }
    }
    $titles{$key} = $self->{srcFile};
    return;
}


sub _check_date {
    my ($self) = @_;

    my $published_when = trim($self->{meta_data}->{published}->{when});
    my $published_where = trim($self->{meta_data}->{published}->{where});
    return unless($published_when);

    foreach my $c (@comics) {
        next if ($c == $self);
        my $pub_when = trim($c->{meta_data}->{published}->{when});
        my $pub_where = trim($c->{meta_data}->{published}->{where});

        next unless(defined $pub_when);
        foreach my $l ($self->_languages()) {
            next if ($self->_is_for($l) != $c->_is_for($l));
            if ($published_when eq $pub_when && $published_where eq $pub_where) {
                $self->_croak("duplicated date with $c->{srcFile}");
            }
        }
    }
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
            $self->_croak("In layer $label: $1");
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
        $self->_croak("In JSON$where: $what");
    }
    return;
}


sub _check_frames {
    my ($self) = @ARG;

    my $prev_y;
    my $prev_bottom;
    my $prev_x;
    my $prev_side;

    my $left_side;
    my $right_side;

    my $first_row = 1;

    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $frame_xpath = _build_xpath('g[@inkscape:label="Rahmen"]', 'rect');
    ## use critic
    foreach my $f (sort _framesort $self->{xpath}->findnodes($frame_xpath)) {
        $self->_check_frame_style($f);

        my $y = $f->getAttribute('y') * 1.0;
        my $bottom = $y + $f->getAttribute('height') * 1.0;
        my $x = $f->getAttribute('x') * 1.0;
        $left_side = $x unless (defined $left_side);

        my $side = $x + $f->getAttribute('width') * 1.0;
        my $next_row = defined($prev_y) && _more_off($prev_y, $y, $FRAME_ROW_HEIGHT);
        $first_row = 0 if ($next_row);
        $right_side = $side if ($first_row);

        if (defined $prev_y) {
            if ($next_row) {
                if ($prev_bottom > $y) {
                    $self->_croak("frames overlap y at $prev_bottom and $y");
                }
                if ($prev_bottom + $FRAME_SPACING > $y) {
                    $self->_croak('frames too close y (' . ($prev_bottom + $FRAME_SPACING - $y) . "at $prev_bottom and $y");
                }
                if ($prev_bottom + $FRAME_SPACING + $FRAME_SPACING_TOLERANCE < $y) {
                    $self->_croak("frames too far y at $prev_bottom and $y");
                }

                if (_more_off($left_side, $x, $FRAME_TOLERANCE)) {
                    $self->_croak("frame left side not aligned: $left_side and $x");
                }
                if (_more_off($prev_side, $right_side, $FRAME_TOLERANCE)) {
                    $self->_croak("frame right side not aligned: $prev_side and $right_side");
                }
            }
            else {
                if (_more_off($prev_y, $y, $FRAME_TOLERANCE)) {
                    $self->_croak("frame tops not aligned: $prev_y and $y");
                }
                if (_more_off($prev_bottom, $bottom, $FRAME_TOLERANCE)) {
                    $self->_croak("frame bottoms not aligned: $prev_bottom and $bottom");
                }

                if ($prev_side > $x) {
                    $self->_croak("frames overlap x at $prev_side and $x");
                }
                if ($prev_side + $FRAME_SPACING > $x) {
                    $self->_croak("frames too close x at $prev_side and $x");
                }
                if ($prev_side + $FRAME_SPACING + $FRAME_SPACING_TOLERANCE < $x) {
                    $self->_croak('frames too far x (' . ($x - ($prev_side + $FRAME_SPACING + $FRAME_SPACING_TOLERANCE)) . ") at $prev_side and $x");
                }
            }
        }

        $prev_y = $y;
        $prev_bottom = $bottom;
        $prev_x = $x;
        $prev_side = $side;
    }
    return;
}


sub _framesort {
    # Need to normalize, so that e.g., y 0 and 0.5 are considered in the same row.
    # No need to normalize x, these values are not close together for a row.
    return _rowify($a->getAttribute('y')) <=> _rowify($b->getAttribute('y'))
        || $a->getAttribute('x') <=> $b->getAttribute('x');
}


sub _rowify {
    my $y = shift;
    return floor($y / $FRAME_ROW_HEIGHT); # too much? just use 10 to move the comma?
}


sub _check_frame_style {
    my ($self, $f) = @ARG;

    my $style = $f->getAttribute('style');
    if ($style =~ m{;stroke-width:([^;]+);}) {
        my $width = $1;
        if ($width < $FRAME_WIDTH - $FRAME_WIDTH_DEVIATION) {
            $self->_croak("Frame too narrow ($width)");
        }
        if ($width > $FRAME_WIDTH + $FRAME_WIDTH_DEVIATION) {
            $self->_croak("Frame too wide ($width)");
        }
    }
    else {
        $self->_croak("Cannot find width in '$style'");
    }
    return;
}


sub _more_off {
    my ($a, $b, $dist) = @ARG;
    return abs($a - $b) > $dist;
}


sub _check_tags {
    my ($self, $what, $language) = @ARG;

    foreach my $tag (@{$self->{meta_data}->{$what}->{$language}}) {
        $self->_croak("No $language $what") unless(defined $tag);
        $self->_croak("Empty $language $what") if ($tag =~ m/^\s*$/);
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

    my $trace = '';
    my $previous = '';
    my $allow_duplicated = $self->{meta_data}->{'allow-duplicated'} || [];
    my %allow_duplicated = map { $_ => 1 } @{$allow_duplicated};
    foreach my $t ($self->_texts_for($language)) {
        # Check for copy paste errors: copied texts and forgotten to adjust
        foreach my $l ($self->_languages()) {
            next if ($l eq $language);
            foreach my $ot ($self->_texts_for($l)) {
                my $trimmed = trim($t);
                if ($trimmed eq trim($ot)) {
                    if (defined $allow_duplicated{$trimmed}) {
                        # Ok, explicitly allowed to be duplicated.
                    }
                    elsif ($t =~ m{^\w+:$}) {
                        # Ok, looks like a name / speaker introduction.
                        # Should this also check that it's found in a meta layer?
                    }
                    else {
                        $self->_croak("duplicated text '$t' in $language and $l");
                    }
                }
            }
        }

        # Check for mixed up order (two speaker indicators after another).
        $trace .= "[$t]";
        if (_both_names($previous, $t)) {
            $self->_croak("transcript mixed up in $language: $trace");
        }
        $previous = $t;
    }

    # Check that the comic does not end with a speaker indicator.
    if (trim($previous) =~ m{:$}) {
        $self->_croak("speaker's text missing after '$previous'");
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
    my ($self, $language) = @ARG;

    # Hide all but current language layers
    my $had_lang = 0;
    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $all_layers = _build_xpath('g[@inkscape:groupmode="layer"]');
    ## use critic
    foreach my $layer ($self->{xpath}->findnodes($all_layers)) {
        my $label = $layer->{'inkscape:label'};
        $layer->{'style'} = 'display:inline' unless (defined($layer->{'style'}));
        foreach my $other_lang ($self->_languages()) {
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
        $self->_croak("no $language layer");
    }
    return;
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
    my ($self, $language) = @ARG;

    my $temp_file_name = $self->_make_file_name($language, 'tmp/svgs', 'svg');
    $self->{dom}->toFile($temp_file_name);
    return $temp_file_name;
}


sub _svg_to_png {
    my ($self, $language, $svg_file, $png_file) = @ARG;

    my $export_cmd = "inkscape --without-gui --file=$svg_file" .
        ' --g-fatal-warnings' .
        " --export-png=$png_file --export-area-drawing --export-background=#ffffff";
    system($export_cmd) && $self->_croak("could not export: $export_cmd: $OS_ERROR");

    my $tool = Image::ExifTool->new();
    $self->_set_png_meta($tool, 'Title', $self->{meta}->{title}->{$language});
    $self->_set_png_meta($tool, 'Artist', 'Robert Wenner');
    my $transcript = '';
    foreach my $t ($self->_texts_for($language)) {
        $transcript .= ' ' unless ($transcript eq '');
        $transcript .=  $t;
    }
    $self->_set_png_meta($tool, 'Description', $transcript);
    $self->_set_png_meta($tool, 'CreationTime', $self->{modified});
    $self->_set_png_meta($tool, 'Copyright', 'CC BY-NC-SA 4.0');
    $self->_set_png_meta($tool, 'URL', $self->_make_url($language, 'png'));
    my $rc = $tool->WriteInfo($png_file);
    if ($rc != 1) {
        $self->_croak('cannot write info: ' . tool->GetValue('Error'));
    }

    my $shrink_cmd = "optipng --quiet $png_file";
    system($shrink_cmd) && $self->_croak("Could not shrink: $shrink_cmd: $OS_ERROR");

    return;
}


sub _set_png_meta {
    my ($self, $tool, $name, $value) = @ARG;

    my ($count_set, $error) = $tool->SetNewValue($name, $value);
    $self->_roak("Cannot set $name: $error") if ($error);
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

    return _make_dir(lc($language) . "/$where/") . $self->_normalized_title($language) . ".$ext";
}


sub _make_dir {
    my $dir = 'generated/' . shift;

    unless (-d $dir) {
        File::Path::make_path($dir) or croak("Cannot mkdir $dir: $OS_ERROR");
    }
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
    $self->_croak("No $language title in $self->{srcFile}") unless($title);
    $title =~ s/&\w+;//g;
    $title =~ s/\s{2}/ /g;
    $title =~ s/\s/-/g;
    $title =~ s/[^\w\d_-]//gi;
    return lc $title;
}


=head2 export_all_html

Generates a HTML page for each Comic that has been loaded.

The HTML page will be the same name as the generated PNG, with a .html
extension and will be placed next to it.

=cut

sub export_all_html {
    my %languages;
    foreach my $c (@comics) {
        foreach my $language ($c->_languages()) {
            $languages{$language} = 1;
            my $name = $c->_make_file_name($language, 'web/comics', 'html');
            $c->{htmlFile}{$language} = basename($name);
            $c->{pngFile}{$language} = basename($name);
            $c->{pngFile}{$language} =~ s/\.html$/\.png/;
            $c->{url}{$language} = $c->_make_url($language, 'html');
        }
    }

    my @sorted = sort _compare @comics;
    foreach my $i (0 .. @sorted - 1) {
        my $comic = $sorted[$i];
        foreach my $language ($comic->_languages()) {
            my $first_comic = _find_next($language, $i, \@sorted, [0 .. $i - 1]);
            $comic->{'first'}{$language} = $first_comic ? $first_comic->{htmlFile}{$language} : 0;
            my $prev_comic = _find_next($language, $i, \@sorted, [reverse 0 .. $i - 1]);
            $comic->{'prev'}{$language} = $prev_comic ? $prev_comic->{htmlFile}{$language} : 0;
            my $next_comic = _find_next($language, $i, \@sorted, [$i + 1 .. @sorted - 1]);
            $comic->{'next'}{$language} = $next_comic ? $next_comic->{htmlFile}{$language} : 0;
            my $last_comic = _find_next($language, $i, \@sorted, [reverse $i + 1 .. @sorted - 1]);
            $comic->{'last'}{$language} = $last_comic ? $last_comic->{htmlFile}{$language} : 0;
            $comic->_export_language_html($language);
        }
    }

    my %vars;
    $vars{'comics'} = [ @sorted ];
    $vars{'notFor'} = \&_not_published_on_the_web;
    foreach my $language (keys %languages) {
        my $templ = $text{'sitemapXmlTemplateFile'}{$language};
        my $xml =_templatize('(none)', $templ, %vars)
            or croak "Error templatizing $templ: $OS_ERROR";
        _write_file($text{'sitemapXmlTo'}{$language}, $xml);
    }

    return;
}


sub _languages {
    my ($self) = @ARG;

    my @languages;
    push @languages, keys $self->{meta_data}->{title};
    return @languages;
}


sub _not_yet_published {
    my ($self) = @ARG;

    return 1 if ($self->{meta_data}->{published}->{where} ne 'web');

    Readonly my $DAYS_PER_WEEK => 7;
    Readonly my $THURSDAY => 4;

    my $till = _now();
    $till->set_time_zone(_get_tz());
    my $dow = $till->day_of_week();
    if ($dow == $THURSDAY) {
        # On Thursday, already add next day's comic. That way, when the web
        # site update script runs on 23:58 on Thursday or on 00:00:02 on
        # Friday night, it will already have the comic for the next push.
        # When I run the script on any other day of the week it will just
        # have what is already published and I can easily upload changes
        # in e.g., pages without publishing new comics.
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
    my ($self, $language) = @ARG;

    my $path = $self->_not_yet_published() ? 'backlog' : lc($language) . '/web/comics';
    my $page = "generated/$path/$self->{pngFile}{$language}";
    $page =~ s{\.png$}{.html};
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


sub _not_published_on_the_web {
    my ($self, $language) = @ARG;
    return !$self->_is_for($language) || $self->_not_yet_published();
}


sub _do_export_html {
    my ($self, $language) = @ARG;

    my %vars;
    my $title = $self->{meta_data}->{title}->{$language};
    # SVG, being XML, needs to encode XML special characters, but does not do
    # HTML encoding. So first reverse the XML encoding, then apply any HTML
    # encoding.
    $vars{title} = encode_entities(decode_entities($title));
    $vars{png_file} = $self->{pngFile}{$language};
    $vars{modified} = $self->{modified};
    $vars{height} = $self->{height};
    $vars{width} = $self->{width};
    $vars{'url'} = $self->{url}{$language};
    $vars{'image'} = $self->{url}{$language} || ''; # for tests that don't fake this
    $vars{'image'} =~ s/\.html$/.png/;
    $vars{'first'} = $self->{'first'}{$language};
    $vars{'prev'} = $self->{'prev'}{$language};
    $vars{'next'} = $self->{'next'}{$language};
    $vars{'last'} = $self->{'last'}{$language};
    $vars{'languages'} = [grep { $_ ne $language } sort $self->_languages()];
    $vars{'languagecodes'} = { $self->_language_codes() };
    $vars{'languageurls'} = $self->{url};
    $vars{'languagetitles'} = $self->{meta_data}->{title};
    $vars{'who'} = [@{$self->{meta_data}->{who}->{$language}}];
    $vars{'published'} = trim($self->{meta_data}->{published}->{when});
    Readonly my $DIGITS_YEAR => 4;
    $vars{'year'} = substr $vars{'published'}, 0, $DIGITS_YEAR;
    $vars{'keywords'} = '';
    if (defined($self->{meta_data}->{tags}->{$language})) {
        $vars{'keywords'} = join q{,}, @{$self->{meta_data}->{tags}->{$language}};
    }

    # By default, use normal path with comics in comics/
    my $path = '../';
    # Adjust the path for backlog comics.
    $path = '../' . lc($language) . '/web/' if ($self->_not_yet_published());
    # Adjust the path for top-level index.html
    if ($self->{isLatestPublished}) {
        $path = '';
        $vars{png_file} = 'comics/' . basename($vars{png_file});
        $vars{'first'} = 'comics/' . $self->{'first'}{$language};
        $vars{'prev'} = 'comics/' . $self->{'prev'}{$language};
    }
    $vars{'root'} = $path;
    my $contrib = $self->{meta_data}->{contrib};
    $vars{'contrib'} = 0;
    if (defined($contrib) && join('', @{$contrib}) !~ m{^\s*$}) {
        $vars{'contrib'} = $contrib;
    }

    $vars{transcriptHtml} = '';
    $vars{transcriptJson} = '';
    foreach my $t ($self->_texts_for($language)) {
        $vars{transcriptHtml} .= '<p>' . encode_entities($t) . "</p>\n";
        $vars{transcriptJson} .= ' ' unless ($vars{transcriptJson} eq '');
        $vars{transcriptJson} .= $t;
    }
    $vars{'transcriptJson'} =~ s/"/\\"/mg;
    $vars{'backlog'} = $self->_not_yet_published();

    my $tags = '';
    foreach my $t (@{$self->{meta_data}->{tags}->{$language}}) {
        $tags .= ', ' unless ($tags eq '');
        $tags .= $t;
    }
    $vars{description} = encode_entities($self->{meta_data}->{description}->{$language});
    return _templatize($self->{srcFile}, $text{comicTemplateFile}{$language}, %vars)
        or $self->_croak("Error writing HTML: $OS_ERROR");
}


sub _language_codes {
    my ($self) = @_;

    my %codes;
    LANG: foreach my $lang (keys $self->{meta_data}->{title}) {
        if ($language_code_cache{$lang}) {
            $codes{$lang} = $language_code_cache{$lang};
            next LANG;
        }
        foreach my $lcode (Locales::->new()->get_language_codes()) {
            my $loc = Locales->new($lcode);
            next unless($loc);
            my $code = $loc->get_code_from_language($lang);
            if ($code) {
                $codes{$lang} = $code;
                $language_code_cache{$lang} = $code;
                next LANG;
            }
        }
        $self->croak("cannot find language code for '$lang'");
    }
    return %codes;
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
        $text = trim ($text);

        if ($text eq '') {
            my $layer = $node->parentNode->{'inkscape:label'};
            $self->_croak("empty text in $layer with ID $node->{id}");
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

    my ($x, $y) = ($node->getAttribute('x'), $node->getAttribute('y'));
    if (!defined($node->getAttribute('x')) || !defined($node->getAttribute('y'))) {
        ($x, $y) = _text_from_path($self, $node);
    }
    $self->_croak('no x') unless(defined $x);
    $self->_croak('no y') unless(defined $y);

    my $transform = $node->getAttribute('transform');
    if (!$transform || !$self->{options}{$TRANSFORM}) {
        return $x if ($attribute eq 'x');
        return $y if ($attribute eq 'y');
        return $node->getAttribute($attribute);
    }

    ## no critic(RegularExpressions::ProhibitCaptureWithoutTest)
    # Perl::Critic does not understand the if and croak here.
    if ($transform !~ m/^(\w+)\(([^)]+)\)$/) {
        $self->_croak('Cannot handle multiple transformations');
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
        $self->_croak("Unsupported operation $operation");
    }
    # http://www.w3.org/TR/SVG/coords.html#TransformMatrixDefined
    # a c e   x
    # b d f * y
    # 0 0 1   1
    # FIXME: Ignores inkscape:transform-center-x and inkscape:transform-center-y
    # attributes.
    return $a * $x + $c * $y if ($attribute eq 'x');
    return $b * $x + $d * $y if ($attribute eq 'y');
    $self->_croak("Unsupported attribute $attribute to transform");
    return; # PerlCritic does not see that this is unreachable.
}


sub _text_from_path {
    my ($self, $node) = @ARG;

    my @text_path = $node->getChildrenByTagName('textPath');
    $self->_croak('No X/Y and no textPath child element') if (@text_path == 0);
    $self->_croak('No X/Y and multiple textPath child elements') if (@text_path > 1);
    my $path_id = $text_path[0]->getAttribute('xlink:href');
    $path_id =~ s{^#}{};
    my $xpath = "//$DEFAULT_NAMESPACE:ellipse[\@id='$path_id']";
    my @path_nodes = $self->{xpath}->findnodes($xpath);
    $self->_croak("$xpath not found") if (@path_nodes == 0);
    $self->_croak("More than one node with ID $path_id") if (@path_nodes > 1);
    my $type = $path_nodes[0]->nodeName;
    $self->_croak("Cannot handle $type nodes") unless ($type eq 'ellipse');
    return ($path_nodes[0]->getAttribute('cx'), $path_nodes[0]->getAttribute('cy'));
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
    my ($comic_file, $template_file, %vars) = @ARG;

    my %options = (
        STRICT => 1,
        # PRE_CHOMP => 1, removes space in "with ideas from [% who %]"
        POST_CHOMP => 2,
        # TRIM => 1,
    );
    my $t = Template->new(%options) ||
        croak('Cannot construct template: ' . Template->error());
    my $output = '';
    my $template = _slurp($template_file);
    $t->process(\$template, \%vars, \$output) ||
        croak "$template_file for $comic_file: " . $t->error() . "\n";

    if ($output =~ m/\[%/mg || $output =~ m/%\]/mg) {
        croak "$template_file for $comic_file: Unresolved template marker";
    }
    if ($output =~ m/ARRAY\(0x[[:xdigit:]]+\)/mg) {
        croak "$template_file for $comic_file: ARRAY ref found:\n$output";
    }
    if ($output =~ m/HASH\(0x[[:xdigit:]]+\)/mg) {
        croak "$template_file for $comic_file: HASH ref found:\n$output";
    }
    return $output;
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
    my ($backlog_template, %archive_templates) = @ARG;

    foreach my $c (@comics) {
        foreach my $language (keys %archive_templates) {
            next unless ($c->_is_for($language));

            my $dir = $c->_not_yet_published() ? 'backlog/' : 'comics/';
            my $name = $c->{pngFile}{$language};
            $name =~ s{\.png$}{.html};
            $c->{href}{$language} = $dir . basename($name);
        }
    }

    foreach my $language (keys %archive_templates) {
        my @sorted = (sort _compare grep { _archive_filter($_, $language) } @comics);
        next if (@sorted == 0);
        my $last_pub = $sorted[-1];
        $last_pub->{isLatestPublished} = 1;
        my $page = _make_dir(lc($language) . '/web') . '/index.html';
        _write_file($page, $last_pub->_do_export_html($language));
    }

    _do_export_archive(%archive_templates);
    _do_export_backlog($backlog_template, sort keys %archive_templates);
    return;
}


sub _archive_filter {
    my ($comic, $language) = @ARG;
    return !$comic->_not_yet_published() && $comic->_is_for($language)
}


sub _backlog_filter {
    my ($comic) = @ARG;
    return $comic->_not_yet_published();
}


sub _do_export_archive {
    my (%archive_templates) = @ARG;

    foreach my $language (sort keys %archive_templates) {
        my $page = 'generated/' . lc($language) . "/web/$text{archivePage}{$language}";

        my @filtered = sort _compare grep { _archive_filter($_, $language) } @comics;
        if (!@filtered) {
            _write_file($page, '<p>No comics in archive.</p>');
            next;
        }

        my %vars;
        $vars{'title'} = $text{archiveTitle}{$language};
        $vars{'url'} = $text{archivePage}{$language};
        $vars{'root'} = '';
        $vars{'comics'} = \@filtered;
        $vars{'modified'} = $filtered[-1]->{modified};
        $vars{'notFor'} = \&_not_for;

        my $templ_file = $text{archiveTemplateFile}{$language};
        _write_file($page, _templatize('archive', $templ_file, %vars));
    }

    return;
}


sub _do_export_backlog {
    my ($templ_file, @languages) = @ARG;
    # @fixme weird mix of hard-coded and passed file names

    my $page = "generated/$text{backlogPage}";
    my @filtered = sort _compare grep { _backlog_filter($_) } @comics;
    if (!@filtered) {
        _write_file($page, '<p>No comics in backlog.</p>');
        return;
    }

    my %vars;
    $vars{'languages'} = \@languages;
    $vars{'comics'} = \@filtered;
    $vars{'notFor'} = \&_not_for;
    $vars{'archive'} = \$text{archivePage};
    $vars{'publishers'} = _publishers();

    _write_file($page, _templatize('backlog', $templ_file, %vars));

    return;
}


sub _publishers {
    my %publishers = map {
        $_->{meta_data}->{published}->{where} => 1
    } grep {
        $_->{meta_data}->{published}->{where} ne 'web'
    } @comics;
    return ['web', sort {lc $a cmp lc $b} keys %publishers];
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

    =item B<$template> path / file name of the template file.

    =item B<$language> path / file name of the generated sizemap.

=back

=cut

sub size_map {
    my ($template, $output) = @_;
    my %aggregate = _aggregate_comic_sizes();

    Readonly my $SCALE_BY => 0.3;
    my $svg = SVG->new(
        width => $aggregate{width}{'max'} * $SCALE_BY,
        height => $aggregate{height}{'max'} * $SCALE_BY,
        -printerror => 1,
        -raiseerror => 1);

    foreach my $comic (@comics) {
        my $color = 'green';
        $color = 'blue' if ($comic->_not_yet_published());
        $svg->rectangle(x => 0, y => 0,
            width => $comic->{width} * $SCALE_BY,
            height => $comic->{height} * $SCALE_BY,
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
            $vars{"$agg$dim"} = $aggregate{$dim}{$agg} || 'n/a';
        }
    }
    $vars{'height'} = $aggregate{height}{'max'} * $SCALE_BY;
    $vars{'width'} = $aggregate{width}{'max'} * $SCALE_BY;
    $vars{'comics_by_width'} = [sort _by_width @comics];
    $vars{'comics_by_height'} = [sort _by_height @comics];
    $vars{svg} = $svg->xmlify();
    # Remove XML declaration and doctype; Firefox marks them red in the source
    # view of the page.
    $vars{svg} =~ s/<\?xml[^>]+>\n//;
    $vars{svg} =~ s/<!DOCTYPE[^>]+>\n//;

    _write_file($output, _templatize('size map', $template, %vars));

    return;
}


sub _aggregate_comic_sizes {
    my %aggregate;

    my %inits = (
        'min' => 9_999_999,
        'max' => 0,
        'avg' => 0,
        'cnt' => 0,
    );
    foreach my $agg (qw(min max avg cnt)) {
        foreach my $dim (qw(height width)) {
            $aggregate{$dim}{$agg} = $inits{$agg};
        }
    }

    foreach my $comic (@comics) {
        foreach my $dim (qw(height width)) {
            if ($aggregate{$dim}{'min'} > $comic->{$dim}) {
                $aggregate{$dim}{'min'} = $comic->{$dim};
            }
            if ($aggregate{$dim}{'max'} < $comic->{$dim}) {
                $aggregate{$dim}{'max'} = $comic->{$dim};
            }
            $aggregate{$dim}{'avg'} += $comic->{$dim};
            $aggregate{$dim}{'cnt'}++;
        }
    }

    foreach my $dim (qw(height width)) {
        if (($aggregate{$dim}{'cnt'} || 0) == 0) {
            $aggregate{$dim}{avg} = 'n/a';
        }
        else {
            $aggregate{$dim}{avg} /= $aggregate{$dim}{'cnt'};
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


=head2 export_rss_feed

Writes an RSS feed XML for all comics and each language encountered.

Parameters:

=over 4

    =item B<$items> number of comics to include in the feed.

    =item B<$toFile> to which file to write the feed, e.g., rss.xml. This
        will be within 'generated/<language>/web'.

    =item B<%templates> hash of language to RSS template file name.

=back

=cut

sub export_rss_feed {
    my ($items, $to, %templates) = @ARG;

    foreach my $language (keys %templates) {
        my %vars = (
            'comics' => [reverse sort _compare grep { _archive_filter($_, $language) } @comics],
            'notFor' => \&_not_for,
            'max' => $items,
        );
        my $rss =_templatize('(none)', $templates{$language}, %vars)
            or croak "Error templatizing $templates{$language}: $OS_ERROR";
        _write_file('generated/' . lc($language) . "/web/$to", $rss);
    }
    return;
}


sub _croak {
    my ($self, $msg) = @_;
    croak "$self->{srcFile}: $msg";
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
