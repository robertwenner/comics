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
use DateTime::Format::RFC3339;
use File::Path qw(make_path);
use File::Basename;
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use XML::LibXML;
use XML::LibXML::XPathContext;
use JSON;
use HTML::Entities;
use Image::ExifTool qw(:Public);
use Image::SVG::Transform;
use Imager::QRCode;
use Template;
use Template::Plugin::JSON;
use SVG;
use URI::Encode qw(uri_encode uri_decode);
use Net::Twitter;
use Reddit::Client;
use Clone qw(clone);


use version; our $VERSION = qv('0.0.2');

=for stopwords inkscape html svg png Wenner merchantability perlartistic MetaEnglish rss sitemap sizemap xml dbus


=head1 NAME

Comic - Converts SVG comics to png by language and creates HTML pages.


=head1 VERSION

This document refers to version 0.0.2.


=head1 SYNOPSIS

    use Comic;

    foreach my $file (@ARGV) {
        my $c = Comic->new($file, (
            'Deutsch' => 'biercomics.de',
            'English' => 'beercomics.com'));
        $c->export_png();
    }
    Comic::export_all_html(
        { # comic templates
            'English' => 'templates/english/comic-page.templ',
            'Deutsch' => 'templates/deutsch/comic-page.templ',
        },
        { # sitemap templates
            'English' => 'templates/english/sitemap-xml.templ',
            'Deutsch' => 'templates/deutsch/sitemap-xml.templ',
        },
        { # sitemap output
            'English' => 'generated/english/web/sitemap.xml',
            'Deutsch' => 'generated/deutsch/web/sitemap.xml',
        },
    );
    Comic::export_archive('templates/backlog.templ', 'generated/backlog.html',
        { # archive page template
            "Deutsch" => "templates/deutsch/archiv.templ",
            "English" => "templates/english/archive.templ",
        },
        { # path and file name of the generated archive
            'Deutsch' => 'generated/web/deutsch/archiv.html',
            'English' => 'generated/web/english/archive.html',
        },
        { # index.html template is the same as regular comic templates
            'English' => 'templates/english/comic-page.templ',
            'Deutsch' => 'templates/deutsch/comic-page.templ',
        });
    Comic::export_feed(10, 'rss.xml', (
        'Deutsch' => 'templates/deutsch/rss.templ',
        'English' => 'templates/english/rss.templ',
    ));
    Comic::export_feed(10, 'atom.xml', (
        'Deutsch' => 'templates/deutsch/atom.templ',
        'English' => 'templates/english/atom.templ',
    ));
    Comic::size_map('templates/sizemap.templ', 'generated/sizemap.html');
    print Comic::post_to_social_media('English');

=head1 DESCRIPTION

From on an Inkscape SVG file, exports language layers to create per language
PNG files. Creates a RSS or Atom feed and a transcript per language for
search engines. Creates an archive overview page, a backlog page of not yet
published comics, and a sizemap to compare image sizes.

=cut


# XPath default namespace name.
Readonly our $DEFAULT_NAMESPACE => 'defNs';
# What date to use for sorting unpublished comics.
Readonly our $UNPUBLISHED => '3000-01-01';
# Expected frame thickness in pixels.
Readonly our $FRAME_WIDTH => 1.25;
# Tolerance in pixels when looking for frames.
Readonly our $FRAME_TOLERANCE => 1.0;
# Allowed deviation from expected frame width in pixels.
Readonly our $FRAME_WIDTH_DEVIATION => 0.25;
# After how many pixels a frame is assumed to be in the next row.
Readonly our $FRAME_ROW_HEIGHT => 10;
# How many pixels space there should be between frames (both x and y).
Readonly our $FRAME_SPACING => 10;
# Maximum tolerance in pixels for distance between frames.
Readonly our $FRAME_SPACING_TOLERANCE => 2.0;


my %counts;
my %titles;
my %language_code_cache;
my @comics;


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic from an Inkscape SVG file.

Parameters:

=over 4

=item B<$path/file> path and file name to the SVG input file.

=back

=cut

sub new {
    my ($class, $file, %domains) = @ARG;
    my $self = bless{}, $class;
    $self->{options} = {};
    $self->_load($file, %domains);
    return $self;
}


sub _load {
    my ($self, $file, %domains) = @ARG;

    $self->{srcFile} = $file;
    $self->{warnings} = [];
    $self->{dom} = _parse_xml(_slurp($file));
    $self->{xpath} = XML::LibXML::XPathContext->new($self->{dom});
    $self->{xpath}->registerNs($DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $meta_xpath = _build_xpath('metadata/rdf:RDF/cc:Work/dc:description/text()');
    my $meta_data = join ' ', $self->{xpath}->findnodes($meta_xpath);
    eval {
        $self->{meta_data} = from_json(_unhtml($meta_data));
    } or $self->_croak("Error in JSON for: $EVAL_ERROR");

    my $modified = DateTime->from_epoch(epoch => _mtime($file));
    $modified->set_time_zone(_get_tz());
    $self->{modified} = $modified->ymd;
    # $self->{rfc3339Modified} = DateTime::Format::RFC3339->new()->format_datetime($modified);
    my $pub = trim($self->{meta_data}->{published}->{when});
    if ($pub) {
        my $published = DateTime::Format::ISO8601->parse_datetime($pub);
        $published->set_time_zone(_get_tz());
        # DateTime::Format::Mail does RFC822 dates, but uses spaces instead of
        # zeros for single digit numbers. The W3C validator complains about
        # these, saying they're not strictly illegal, but may be a compatibiliy
        # issue.
        $self->{rfc822pubDate} = $published->strftime('%a, %d %b %Y %H:%M:%S %z');
        $self->{rfc3339pubDate} = DateTime::Format::RFC3339->new()->format_datetime($published);
    }

    my %uri_encoding_options = (encode_reserved => 1);
    foreach my $language ($self->_languages()) {
        $self->_croak("No domain for $language") unless (defined $domains{$language});

        my $base;
        if ($self->not_yet_published()) {
            $base = 'backlog/' . lc $language;
        }
        else {
            $base = 'web/' . lc $language . '/comics';
        }

        $self->{titleUrlEncoded}{$language} = uri_encode($self->{meta_data}->{title}->{$language}, %uri_encoding_options);
        $self->{whereTo}{$language} = _make_dir($base);
        $self->{baseName}{$language} = $self->_normalized_title($language);
        $self->{htmlFile}{$language} = "$self->{baseName}{$language}.html";
        $self->{pngFile}{$language} = "$self->{baseName}{$language}.png";
        $self->{domain}{$language} = $domains{$language};
        $self->{url}{$language} = "https://$domains{$language}/comics/$self->{baseName}{$language}.html";
        $self->{urlUrlEncoded}{$language} = uri_encode($self->{url}{$language}, %uri_encoding_options);
        $self->{imageUrl}{$language} = "https://$domains{$language}/comics/$self->{baseName}{$language}.png";
        $self->{href}{$language} = "comics/$self->{htmlFile}{$language}";
    }

    push @comics, $self;
    return;
}


sub _parse_xml {
    my ($xml) = @ARG;
    my $parser = XML::LibXML->new();
    $parser->set_option(huge => 1);
    return $parser->load_xml(string => $xml);
}


sub _append_speech_to_speaker {
    my @texts;
    my $prev = '';
    foreach my $t (@ARG) {
        if ($prev =~ m/:$/) {
            pop @texts;
            push @texts, "$prev $t";
        }
        else {
            push @texts, $t;
        }
        $prev = $t;
    }
    return @texts;
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

Exports PNGs for all languages with meta data in this Comic.

The png file will be the lower case title of the comic, limited to letters,
numbers, and hyphens only. It will be placed in F<generated/web/$language/>.

Inkscape files must have meta data matching layer names, e.g., "English" in
the meta data and an "English" layer and an "MetaEnglish" layer

=cut

sub export_png {
    my ($self, $dont_publish_marker, %meta_data) = @ARG;

    foreach my $language ($self->_languages()) {
        $counts{'comics'}{$language}++;

        unless (_up_to_date($self->{srcFile}, "$self->{whereTo}{$language}/$self->{pngFile}{$language}")) {
            $self->_flip_language_layers($language);
            my $language_svg = $self->_write_temp_svg_file($language);
            $self->_svg_to_png($language, $language_svg, %meta_data);
        }
        $self->_get_png_info("$self->{whereTo}{$language}/$self->{pngFile}{$language}", $language);
    }
    $self->_count_tags();
    return;
}


=head2 check

Runs some checks on this comic.

Parameters:

=over 4

=item B<dont_publish_marker> marker that indicates a comic should not be
    published. If this marker is found in the comic, the export fails.

=back

=cut

sub check {
    my ($self, $dont_publish_marker) = @_;

    foreach my $language ($self->_languages()) {
        $self->_get_transcript($language);
        $self->_check_title($language);
        $self->_check_tags('tags', $language);
        $self->_check_tags('who', $language);
        $self->_check_empty_texts($language);
        $self->_check_transcript($language);
        $self->_check_series($language);
        $self->_check_persons($language);
        $self->_check_meta($language);
    }
    $self->_check_date();
    $self->_check_frames();
    $self->_check_dont_publish($dont_publish_marker);
    return;
}


sub _get_transcript {
    my ($self, $language) = @ARG;

    if (!defined($self->{transcript}{$language})) {
        @{$self->{transcript}{$language}} = _append_speech_to_speaker($self->_texts_for($language));
    }
    return @{$self->{transcript}{$language}};
}


sub _up_to_date {
    # Takes file names as arguments rather than being a member method for
    # easier mocking.
    my ($svg_file, $png_file) = @ARG;

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
            $self->_warn("Duplicated $language title '$title' in $titles{$key}");
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

    my $published_date = DateTime::Format::ISO8601->parse_datetime($published_when);
    $published_date->set_time_zone(_get_tz());
    my $today = _now();
    $today->set_time_zone(_get_tz());
    # Allow older beer comics (initial set) to have non-Friday dates.
    Readonly my $FRIDAYS_ONLY => DateTime->new(year => 2016, month => 8, day => 1);
    if (DateTime->compare($published_date, $FRIDAYS_ONLY) > 0) {
        Readonly my $FRIDAY => 5;
        if ($published_date->day_of_week() != $FRIDAY) {
            $self->_warn('scheduled for ' . $published_date->day_name());
        }
    }

    foreach my $c (@comics) {
        next if ($c == $self);
        my $pub_when = trim($c->{meta_data}->{published}->{when});
        my $pub_where = trim($c->{meta_data}->{published}->{where});

        next unless(defined $pub_when);
        foreach my $l ($self->_languages()) {
            next if ($self->_is_for($l) != $c->_is_for($l));
            if ($published_when eq $pub_when && $published_where eq $pub_where) {
                $self->_warn("duplicated date with $c->{srcFile}");
            }
        }
    }
    return;
}


sub _check_dont_publish {
    my ($self, $marker) = @ARG;

    $self->_check_json('', $self->{meta_data}, $marker);
    foreach my $layer ($self->{xpath}->findnodes(_find_layers())) {
        my $text = $layer->textContent();
        my $label = $layer->{'inkscape:label'};
        if ($text =~ m/(\b$marker\b[^\n\r]*)/m) {
            $self->_warn("In layer $label: $1");
        }
    }
    return;
}


sub _check_json {
    my ($self, $where, $what, $marker) = @ARG;

    if (ref($what) eq 'HASH') {
        foreach my $key (keys %{$what}) {
            $self->_check_json("$where > $key", $what->{$key}, $marker);
        }
    }
    elsif (ref($what) eq 'ARRAY') {
        for my $i (0 .. $#{$what}) {
            $self->_check_json($where . '[' . ($i + 1) . ']', $what->[$i], $marker);
        }
    }
    elsif ($what =~ m/$marker/m) {
        $self->_warn("In JSON$where: $what");
    }
    return;
}


sub _check_frames {
    # frame coordinate is top left corner of a rectangle
    # higher y means lower on the page, higher x means further to the right
    my ($self) = @ARG;

    my $prev_bottom;
    my $prev_top;
    my $prev_right;

    my $left_most;
    my $right_most;

    my $first_row = 1;

    foreach my $f ($self->_all_frames_sorted()) {
        $self->_check_frame_style($f);

        my $top = $f->getAttribute('y') * 1.0;
        my $bottom = $top + $f->getAttribute('height') * 1.0;
        my $left_side = $f->getAttribute('x') * 1.0;
        $left_most = $left_side unless (defined $left_most);

        my $right_side = $left_side + $f->getAttribute('width') * 1.0;
        my $next_row = defined($prev_bottom) && _more_off($prev_bottom, $bottom, $FRAME_ROW_HEIGHT);
        $first_row = 0 if ($next_row);
        $right_most = $right_side if ($first_row);
        if (defined $prev_bottom) {
            if ($next_row) {
                if ($prev_bottom > $top) {
                    $self->_warn("frames overlap y at $prev_bottom and $top");
                }
                if ($prev_bottom + $FRAME_SPACING > $top) {
                    $self->_warn('frames too close y (' . ($prev_bottom - $FRAME_SPACING - $top) . ") at $prev_bottom and $top");
                }
                if ($prev_bottom + $FRAME_SPACING + $FRAME_SPACING_TOLERANCE < $top) {
                    $self->_warn("frames too far y at $prev_bottom and $top");
                }

                if (_more_off($left_most, $left_side, $FRAME_TOLERANCE)) {
                    $self->_warn("frame left side not aligned: $left_most and $left_side");
                }
                if (_more_off($prev_right, $right_most, $FRAME_TOLERANCE)) {
                    $self->_warn("frame right side not aligned: $right_side and $right_most");
                }
            }
            else {
                if (_more_off($prev_bottom, $bottom, $FRAME_TOLERANCE)) {
                    $self->_warn("frame bottoms not aligned: $prev_bottom and $bottom");
                }
                if (_more_off($prev_top, $top, $FRAME_TOLERANCE)) {
                    $self->_warn("frame tops not aligned: $prev_top and $top");
                }

                if ($prev_right > $left_side) {
                    $self->_warn("frames overlap x at $prev_right and $left_side");
                }
                if ($prev_right + $FRAME_SPACING > $left_side) {
                    $self->_warn("frames too close x at $prev_right and $left_side");
                }
                if ($prev_right + $FRAME_SPACING + $FRAME_SPACING_TOLERANCE < $left_side) {
                    $self->_warn('frames too far x (' . ($left_side - ($prev_right + $FRAME_SPACING + $FRAME_SPACING_TOLERANCE)) . ") at $prev_right and $left_side");
                }
            }
        }

        $prev_bottom = $bottom;
        $prev_top = $top;
        $prev_right = $right_side;
    }
    return;
}


sub _all_frames_sorted {
    my ($self) = @ARG;

    ## no critic(ValuesAndExpressions::RequireInterpolationOfMetachars)
    my $frame_xpath = _build_xpath('g[@inkscape:label="Rahmen"]', 'rect');
    ## use critic
    # Needs the extra @sorted array cause the behavior of sort in scalar context
    # is undefined. (WTF?!)
    # http://search.cpan.org/~thaljef/Perl-Critic/lib/Perl/Critic/Policy/Subroutines/ProhibitReturnSort.pm
    my @sorted = sort _framesort $self->{xpath}->findnodes($frame_xpath);
    return @sorted;
}


sub _framesort {
    my ($xa, $ya) = ($a->getAttribute('x'), $a->getAttribute('y'));
    my ($xb, $yb) = ($b->getAttribute('x'), $b->getAttribute('y'));

    if (abs($ya - $yb) < $FRAME_ROW_HEIGHT) {
        # If frames are at roughly equal height, they are in the same row, and
        # their x position matters.
        return $xa <=> $xb;
    }
    return $ya <=> $yb;
}


sub _check_frame_style {
    my ($self, $f) = @ARG;

    my $style = $f->getAttribute('style');
    if ($style =~ m{;stroke-width:([^;]+);}) {
        my $width = $1;
        if ($width < $FRAME_WIDTH - $FRAME_WIDTH_DEVIATION) {
            $self->_warn("Frame too narrow ($width)");
        }
        if ($width > $FRAME_WIDTH + $FRAME_WIDTH_DEVIATION) {
            $self->_warn("Frame too wide ($width)");
        }
    }
    else {
        $self->_warn("Cannot find width in '$style'");
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
        $self->_warn("No $language $what") unless(defined $tag);
        $self->_warn("Empty $language $what") if ($tag =~ m/^\s*$/);
    }

    foreach my $comic (@comics) {
        foreach my $oldtag (@{$comic->{meta_data}->{$what}->{$language}}) {
            foreach my $newtag (@{$self->{meta_data}->{$what}->{$language}}) {
                if ($oldtag ne $newtag && lc $oldtag eq lc $newtag) {
                    $self->_warn("$what $newtag and $oldtag from $comic->{srcFile} only differ in case");
                }
            }
        }
    }

    return;
}


sub _check_empty_texts {
    my ($self, $language) = @ARG;

    foreach my $node (sort { $self->_text_pos_sort($a, $b) } $self->{xpath}->findnodes(_text($language))) {
        my $text = _text_content($node);
        if ($text eq '') {
            my $layer = $node->parentNode->{'inkscape:label'};
            $self->_warn("empty text in $layer with ID $node->{id}");
        }
    }
    return;
}


sub _count_tags {
    my ($self) = @ARG;

    foreach my $what ('tags', 'who') {
        next unless ($self->{meta_data}->{$what});
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
        $self->_croak("speaker's text missing after '$previous', trace is $trace");
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


sub _check_series {
    my ($self, $language) = @ARG;

    my $need = $self->_series_for($language);
    foreach my $l ($self->_languages()) {
        next if ($language eq $l);
        my $has = $self->_series_for($l);
        if ($need && !$has) {
            $self->_warn("No series tag for $l but for $language");
        }
        elsif ($need && $need eq $has) {
            $self->_warn("Duplicated series tag '$need' for $l and $language");
        }
    }
    return;
}


sub _series_for {
    my ($self, $language) = @ARG;

    return '' unless ($self->{meta_data}->{series});
    return trim($self->{meta_data}->{series}{$language});
}


sub _check_persons {
    my ($self, $language) = @ARG;

    if (!$self->{meta_data}->{who}) {
        $self->_warn('No persons metadata at all');
        return;
    }
    foreach my $l (keys %{$self->{meta_data}->{who}}) {
        my @one = @{$self->{meta_data}->{who}->{$l}};
        my @two = @{$self->{meta_data}->{who}->{$language}};
        if (scalar @one  ne scalar @two) {
            $self->_warn("Different number of persons in $language and $l");
        }
    }
    foreach my $who (@{$self->{meta_data}->{who}{$language}}) {
        $self->_warn("Empty person name in $language") if ($who =~ m{^\s*$});
    }
    return;
}


sub _check_meta {
    my ($self, $language) = @ARG;

    unless ($self->{xpath}->findnodes(_find_layers("Meta$language"))) {
        $self->_warn("No Meta$language layer");
        return;
    }

    my $first_text = ($self->_texts_for($language))[0];
    my $text_found = 0;
    my $first_text_is_meta = 0;
    foreach my $text ($self->{xpath}->findnodes(_text("Meta$language"))) {
        $text_found = 1;
        if ($first_text eq _text_content($text)) {
            $first_text_is_meta = 1;
        }
    }
    $self->_warn("No texts in Meta$language layer") unless ($text_found);
    $self->_warn("First text in transcript must be from Meta$language, but is $first_text")
        unless ($first_text_is_meta);  # would be nice to show the layer here, too
    return;
}


sub _flip_language_layers {
    my ($self, $language) = @ARG;

    # Hide all but current language layers
    my $had_lang = 0;
    foreach my $layer ($self->{xpath}->findnodes(_find_layers())) {
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


sub _find_layers {
    my (@labels) = @ARG;

    my $xpath = "/$DEFAULT_NAMESPACE:svg//$DEFAULT_NAMESPACE:g[\@inkscape:groupmode='layer'";
    my $had_labels = 0;
    foreach my $l (@labels) {
        if ($had_labels == 0) {
            $xpath .= ' and (';
        }
        elsif ($had_labels > 0) {
            $xpath .= ' or ';
        }
        $xpath .= "\@inkscape:label='$l'";
        $had_labels++;
    }
    $xpath .= ')' if ($had_labels > 0);
    $xpath .= ']';
    return $xpath;
}


sub _build_xpath {
    my (@fragments) = @ARG;

    my $xpath = "/$DEFAULT_NAMESPACE:svg";
    foreach my $p (@fragments) {
        $xpath .= "/$DEFAULT_NAMESPACE:$p";
    }
    return $xpath;
}


sub _text {
    my ($language) = @ARG;
    return _find_layers($language, "Meta$language", "HintergrundText$language") .
        "//$DEFAULT_NAMESPACE:text";
}


sub _write_temp_svg_file {
    my ($self, $language) = @ARG;

    my $temp_file_name = _make_dir('tmp/' . lc $language . '/svg/') . "$self->{baseName}{$language}.svg";
    my $svg = $self->_copy_svg($language);
    _drop_layers($svg, 'Raw');
    $self->_insert_url($svg, $language);
    $svg->toFile($temp_file_name);
    return $temp_file_name;
}


sub _copy_svg {
    my ($self) = @ARG;
    return _parse_xml($self->{dom}->toString());
}


sub _drop_layers {
    my ($svg, @layers) = @ARG;

    my $node = $svg->documentElement()->firstChild();
    _drop_layers_recursively($node, @layers);
    return;
}


sub _drop_layers_recursively {
    my ($node, @layers) = @ARG;

    while ($node) {
        my $next = $node->nextSibling();
        foreach my $child($node->childNodes()) {
            _drop_layers_recursively($child, @layers);
        }
        foreach my $drop (@layers) {
            if ($node->nodeName() eq 'g'
            && ($node->getAttribute('inkscape:groupmode') || '') eq 'layer'
            && ($node->getAttribute('inkscape:label') || '') eq $drop) {
                $node->unbindNode();
            }
        }
        $node = $next;
    }
    return;
}


sub _insert_url {
    my ($self, $svg, $language) = @ARG;

    my $payload = XML::LibXML::Text->new("$self->{domain}{$language} — CC BY-NC-SA 4.0");
    my $tspan = XML::LibXML::Element->new('tspan');
    $tspan->setAttribute('sodipodi:role', 'line');
    $tspan->appendChild($payload);

    my $text = XML::LibXML::Element->new('text');
    my ($x, $y, $transform) = $self->_where_to_place_the_text();
    $text->setAttribute('x', $x);
    $text->setAttribute('y', $y);
    $text->setAttribute('id', 'UrlLicense');
    $text->setAttribute('xml:space', 'preserve');
    my $style = <<'STYLE';
        color:#000000;font-style:normal;font-variant:normal;font-weight:normal;
        font-stretch:normal;font-size:10px;line-height:125%;font-family:
        'Comic Relief';-inkscape-font-specification:'Comic Relief, Normal';
        text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;
        text-anchor:start;clip-rule:nonzero;display:inline;overflow:visible;
        visibility:visible;opacity:1;isolation:auto;mix-blend-mode:normal;.
        color-interpolation:sRGB;color-interpolation-filters:linearRGB;
        solid-color:#000000;solid-opacity:1;fill:#000000;fill-opacity:1;
        fill-rule:nonzero;stroke:none;stroke-width:1px;stroke-linecap:butt;
        stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;
        stroke-dashoffset:0;stroke-opacity:1;color-rendering:auto;
        image-rendering:auto;shape-rendering:auto;text-rendering:auto;
        enable-background:accumulate");
STYLE
    $style =~ s/\s//mg;
    $text->setAttribute('style', $style);
    $text->setAttribute('transform', $transform) if ($transform);

    $text->appendChild($tspan);

    my $layer = XML::LibXML::Element->new('g');
    $layer->setAttribute('inkscape:groupmode', 'layer');
    $layer->setAttribute('inkscape:label', "License$language");
    $layer->setAttribute('style', 'display:inline');
    $layer->setAttribute('id', 'License');
    $layer->appendChild($text);

    my $root = $svg->documentElement();
    $root->appendChild($layer);
    return;
}


sub _where_to_place_the_text {
    my ($self) = @ARG;

    Readonly my $SPACING => 2;
    my ($x, $y, $transform);
    my @frames = $self->_all_frames_sorted();

    if (@frames == 0) {
        # If the comic has no frames, place the text at the bottom.
        # Ask Inkscape about the drawing size.
        my $width = $self->_inkscape_query('W');
        my $height = $self->_inkscape_query('H');
        my $xpos = $self->_inkscape_query('X');
        my $ypos = $self->_inkscape_query('Y');
        $x = $xpos;# - $width;
        $y = $ypos;# + $height;
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
        ($x, $y) = $self->_bottom_right();
        $x = $frames[0]->getAttribute('x') + $frames[0]->getAttribute('width') + $SPACING;
        $y = $frames[0]->getAttribute('y');
        $transform = "rotate(90, $x, $y)";
    }

    return ($x, $y, $transform);
}


sub _inkscape_query {
    my ($self, $what) = @ARG;
    ## no critic( InputOutput::ProhibitBacktickOperators)
    return `inkscape --without-gui -$what $self->{srcFile}`;
    ## use critic
}


sub _frames_in_rows {
    my @frames = @ARG;
    my $prev = shift @frames;
    foreach my $frame (@frames) {
        my $off_by = $frame->getAttribute('y') - $prev->getAttribute('y');
        if ($off_by < -$FRAME_SPACING || $off_by > $FRAME_SPACING) {
            return 1;
        }
        $prev = $frame;
    }
    return 0;
}


sub _svg_to_png {
    my ($self, $language, $svg_file, %global_meta_data) = @ARG;

    my $png_file = "$self->{whereTo}{$language}/$self->{pngFile}{$language}";
    my $export_cmd = "inkscape --without-gui --file=$svg_file" .
        ' --g-fatal-warnings' .
        " --export-png=$png_file --export-area-drawing --export-background=#ffffff";
    _system($export_cmd) && $self->_croak("could not export: $export_cmd: $OS_ERROR");

    my %meta_data = (
        'Title' => $self->{meta_data}->{title}->{$language},
        'Description' => join('', $self->_get_transcript($language)),
        'CreationTime' => $self->{modified},
        'URL' => $self->{url}{$language},
        %global_meta_data,
        ref($self->{meta_data}->{'png-meta-data'}) eq 'HASH' ? %{$self->{meta_data}->{'png-meta-data'}} : (),
    );

    my $tool = Image::ExifTool->new();
    foreach my $m (keys %meta_data) {
        $self->_set_png_meta($tool, $m, $meta_data{$m});
    }

    my $rc = $tool->WriteInfo($png_file);
    if ($rc != 1) {
        $self->_croak('cannot write info: ' . $tool->GetValue('Error'));
    }

    my $shrink_cmd = "optipng --quiet $png_file";
    _system($shrink_cmd) && $self->_croak("Could not shrink: $shrink_cmd: $OS_ERROR");

    return;
}


sub _unhtml {
    # Inkscape is XML, so it uses &lt;, &gt;, &amp;, and &quot; in it's meta
    # data. This is convenient for the HTML export, but not for adding meta
    # data to the .png file.
    my ($text) = @ARG;
    return decode_entities($text);
}


sub _set_png_meta {
    my ($self, $tool, $name, $value) = @ARG;

    my ($count_set, $error) = $tool->SetNewValue($name, $value);
    # @dontCommit
    $self->_croak("Cannot set $name: $error") if ($error);
    return;
}


sub _get_png_info {
    my ($self, $png_file, $language) = @_;

    my $tool = Image::ExifTool->new();
    my $info = $tool->ImageInfo($png_file);

    # @fixme should height and width be different per language?
    $self->{height} = ${$info}{'ImageHeight'};
    $self->{width} = ${$info}{'ImageWidth'};
    $self->{pngSize}{$language} = _file_size($png_file);
    return;
}


sub _file_size {
    my ($name) = @_;

    Readonly my $SIZE => 7;
    return (stat $name)[$SIZE];
}



sub _make_dir {
    my $dir = shift;

    $dir = "generated/$dir" if ($dir !~ m{^generated/});
    unless (-d $dir) {
        File::Path::make_path($dir) or croak("Cannot mkdir $dir: $OS_ERROR");
    }
    return $dir;
}


sub _normalized_title {
    my ($self, $language) = @ARG;

    my $title = $self->{meta_data}->{title}->{$language};
    $self->_croak("No $language title in $self->{srcFile}") unless($title);
    $title =~ s/[&<>*?]//g;
    $title =~ s/\s{2}/ /g;
    $title =~ s/\s/-/g;
    $title =~ s/[^\w\d_-]//gi;
    return lc $title;
}


=head2 export_all_html

Generates a HTML page for each Comic that has been loaded.

The HTML page will be the same name as the generated PNG, with a .html
extension, and it will be placed next to it.

Also generates a sitemap xml file per language.

Parameters:

=over 4

=item B<%comic_templates> hash of language to path / file name of the
comic templates.

=item B<%site_map_templates> hash of language to path / file name of the
sitemap templates.

=item B<%outputs> hash of language to path / file name of the generated
sitemaps.

=back

=cut

sub export_all_html {
    my ($comic_templates, $site_map_templates, $outputs) = @_;

    my @sorted = sort _compare @comics;
    foreach my $i (0 .. @sorted - 1) {
        my $comic = $sorted[$i];
        foreach my $language ($comic->_languages()) {
            # Must export QR code before exporting HTML so that the HTML template can
            # already refer to the QR code URL.
            $comic->_export_qr_code($language);

            my $first_comic = _find_next($language, $i, \@sorted, [0 .. $i - 1]);
            $comic->{'first'}{$language} = $first_comic ? $first_comic->{htmlFile}{$language} : 0;
            my $prev_comic = _find_next($language, $i, \@sorted, [reverse 0 .. $i - 1]);
            $comic->{'prev'}{$language} = $prev_comic ? $prev_comic->{htmlFile}{$language} : 0;
            my $next_comic = _find_next($language, $i, \@sorted, [$i + 1 .. @sorted - 1]);
            $comic->{'next'}{$language} = $next_comic ? $next_comic->{htmlFile}{$language} : 0;
            my $last_comic = _find_next($language, $i, \@sorted, [reverse $i + 1 .. @sorted - 1]);
            $comic->{'last'}{$language} = $last_comic ? $last_comic->{htmlFile}{$language} : 0;
            $comic->_export_language_html($language, ${$comic_templates}{$language});

            _make_dir('web/' . lc $language);
        }
    }

    my %languages;
    foreach my $c (@comics) {
        foreach my $language ($c->_languages()) {
            $languages{$language} = 1;
        }
    }
    my %vars;
    $vars{'comics'} = [ @sorted ];
    $vars{'notFor'} = \&_not_published_on_the_web;
    foreach my $language (keys %languages) {
        my $templ = ${$site_map_templates}{$language};
        my $xml =_templatize('(none)', $templ, $language, %vars);
        _write_file(${$outputs}{$language}, $xml);
    }

    return;
}


sub _languages {
    my ($self) = @ARG;

    my @languages;
    push @languages, keys %{$self->{meta_data}->{title}};
    # Needs the extra @sorted array cause the behavior of sort in scalar context
    # is undefined. (WTF?!)
    # http://search.cpan.org/~thaljef/Perl-Critic/lib/Perl/Critic/Policy/Subroutines/ProhibitReturnSort.pm
    my @sorted = sort @languages;
    return @sorted;
}


=head2 not_yet_published

Checks whether this Comic is not yet published.

=cut

sub not_yet_published {
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
        if (@{$comics}[$i]->not_yet_published() == @{$comics}[$pos]->not_yet_published()) {
            return @{$comics}[$i];
        }

    }
    return 0;
}


sub _export_language_html {
    my ($self, $language, $template) = @ARG;

    $self->_get_transcript($language);
    _write_file("$self->{whereTo}{$language}/$self->{htmlFile}{$language}",
        $self->_do_export_html($language, $template));
    return 0;
}


sub _export_qr_code {
    my ($self, $language) = @ARG;

    my $dir;
    my $png;
    if ($self->_not_published_on_the_web($language)) {
        $dir = 'generated/backlog/qr';
        $png = "../qr/$self->{baseName}{$language}.png";
    }
    else {
        $dir = 'generated/web/' . lc($language) . '/qr';
        $png = "$self->{baseName}{$language}.png";
    }
    $self->{qrcode}{$language} = $png;
    _make_dir($dir);

    my $qrcode = Imager::QRCode::plot_qrcode($self->{url}{$language}, {
        casesensitive => 1,
        mode => '8-bit'
    });
    $qrcode->write(file => "$dir/$png") or $self->_croak($qrcode->errstr);
    return 0;
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
    return !$self->_is_for($language) || $self->not_yet_published();
}


sub _do_export_html {
    my ($self, $language, $template) = @ARG;

    my %vars;
    $vars{'comic'} = $self;
    $vars{'languages'} = [grep { $_ ne $language } $self->_languages()];
    $vars{'languagecodes'} = { $self->_language_codes() };
    # Need clone the URLs so that there is no reference stored here, cause
    # later code may change these vars when creating index.html, but if
    # it's a reference, the actual URL values get changed, too, and that
    # leads to wrong links.
    $vars{'languageurls'} = clone($self->{url});
    Readonly my $DIGITS_YEAR => 4;
    $vars{'year'} = substr $self->{meta_data}->{published}->{when}, 0, $DIGITS_YEAR;
    $vars{'canonicalUrl'} = $self->{url}{$language};

    # By default, use normal path with comics in comics/
    $vars{'comicsPath'} = 'comics/';
    $vars{'indexAdjust'} = '';
    my $path = '../';
    if ($self->not_yet_published()) {
        # Adjust the path for backlog comics.
        $path = '../web/' . lc $language;
    }
    if ($self->{isLatestPublished}) {
        # Adjust the path for top-level index.html: the comics are in their own
        # folder, but index.html is in that folder's parent folder.
        $path = '';
        $vars{'indexAdjust'} = $vars{'comicsPath'};
        foreach my $l (keys %{$vars{'languageurls'}}) {
            # On index.html, link to the other language's index.html, not to
            # the canonical URL of the comic. Google trips over that and thinks
            # there is no backlink.
            ${$vars{'languageurls'}}{$l} =~ s{^(https://[^/]+/).+}{$1};
        }
        # canonicalUrl is different for index.html (main url vs deep link)
        $vars{'canonicalUrl'} =~ s{^(https://[^/]+/).+}{$1};
    }
    if ($self->not_yet_published()) {
        $vars{'root'} = "../$path/";
    }
    else {
        $vars{'root'} = $path;
    }

    $vars{see} = $self->_references($language);
    return _templatize($self->{srcFile}, $template, $language, %vars);
}


sub _language_codes {
    my ($self) = @_;

    my %codes;
    LANG: foreach my $lang (keys %{$self->{meta_data}->{title}}) {
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
        push @texts, _text_content($node);
    }
    return @texts;
}


sub _text_content {
    my ($node) = @ARG;

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
    return $text;
}


sub _find_frames {
    my ($self) = @ARG;

    # Find the frames in the comic. Remember the top of the frames.
    # Assume frames that have their top within a certain $FRAME_TOLERANCE
    # distance from each other are meant to be at the same position.
    my @frame_tops;
    foreach my $f ($self->_all_frames_sorted()) {
        my $y = floor($f->getAttribute('y'));
        my $found = 0;
        foreach my $ff (@frame_tops) {
            $found = 1 if ($ff + $FRAME_TOLERANCE > $y && $ff - $FRAME_TOLERANCE < $y);
        }
        push @frame_tops, $y unless($found);
    }
    @{$self->{frame_tops}} = sort { $a <=> $b } @frame_tops;
    return;
}


sub _text_pos_sort {
    my ($self, $a, $b) = @ARG;

    my ($xa, $ya) = $self->_transformed($a);
    $ya = $self->_pos_to_frame($ya);
    my ($xb, $yb) = $self->_transformed($b);
    $yb = $self->_pos_to_frame($yb);
    return $ya <=> $yb || $xa <=> $xb;
}


sub _transformed {
    my ($self, $node, $attribute) = @ARG;

    my ($x, $y) = ($node->getAttribute('x'), $node->getAttribute('y'));
    if (!defined $x || !defined $y) {
        ($x, $y) = _text_from_path($self, $node);
    }
    $self->_croak('no x') unless(defined $x);
    $self->_croak('no y') unless(defined $y);

    my $transform = $node->getAttribute('transform');
    if ($transform) {
        my $trans = Image::SVG::Transform->new();
        $trans->extract_transforms($transform);
        ($x, $y) = @{$trans->transform([$x, $y])};
    }

    return ($x, $y);
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


sub _pos_to_frame {
    my ($self, $y) = @ARG;

    for my $i (0..@{$self->{frame_tops}} - 1) {
        return $i if ($y < @{$self->{frame_tops}}[$i]);
    }
    return @{$self->{frame_tops}};
}


sub _references {
    my ($self, $language) = @ARG;

    my %links;
    if (!defined $self->{meta_data}->{see} || !defined $self->{meta_data}->{see}{$language}) {
        return \%links;
    }

    my $references = $self->{meta_data}->{see}{$language};
    foreach my $ref (keys %{$references}) {
        my $found = 0;
        foreach my $comic (@comics) {
            if ($comic->{srcFile} eq ${$references}{$ref}) {
                $links{$ref} = $comic->{url}{$language};
                $found = 1;
            }
        }
        if (!$found) {
            $self->_warn("$language link refers to non-existent ${$references}{$ref}");
        }
    }
    return \%links;
}


sub _bottom_right {
    my ($self) = @ARG;

    my @frames = $self->_all_frames_sorted();
    my $bottom_right = $frames[-1];
    # from 0/0, x increases to right, y increases to the bottom
    return ($bottom_right->getAttribute('x') + $bottom_right->getAttribute('width'),
        $bottom_right->getAttribute('y'));
}


sub _templatize {
    my ($comic_file, $template_file, $language, %vars) = @ARG;

    my %options = (
        STRICT => 1,
        PRE_CHOMP => 0, # removes space in beginning of a directive
        POST_CHOMP => 2, # removes spaces after a directive
        # TRIM => 1,    # only used for BLOCKs
        VARIABLES => {
            'Language' => $language,
            'language' => lcfirst($language),
        },
        ENCODING => 'utf8',
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
    # Remove leading white space from lines. Template options don't work
    # cause they also remove newlines.
    $output =~ s/^ *//mg;
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

Parameters:

=over 4

=item B<$backlog_template> path / file name of the template file.

=item B<$backlog_page> path / file name of the generated backlog html.

=item B<%archive_templates> reference to a hash of language to the
archive template file for that language.

=item B<%archive_pages> reference to a hash of language to the archive
page html file.

=item B<$%comic_templates> reference to a hash of language to comic
template file to use for F<index.html>.

=back

=cut

sub export_archive {
    my ($backlog_template, $backlog_page, $archive_templates, $archive_pages, $comic_template) = @ARG;

    _check_all_comics();
    foreach my $language (keys %{$archive_templates}) {
        my @sorted = (sort _compare grep { _archive_filter($_, $language) } @comics);
        next if (@sorted == 0);
        my $last_pub = $sorted[-1];
        $last_pub->{isLatestPublished} = 1;
        my $page = _make_dir('web/' . lc $language);
        $page.= '/index.html';
        _write_file($page, $last_pub->_do_export_html($language, ${$comic_template}{$language}));
    }

    _do_export_archive($archive_templates, $archive_pages);
    _do_export_backlog($backlog_template, $backlog_page, sort keys %{$archive_pages});
    return;
}


sub _check_all_comics {
    _check_all_series();
    return;
}


sub _check_all_series {
    my %series_count;

    foreach my $comic (@comics) {
        next unless (defined($comic->{meta_data}->{series}));
        foreach my $language (keys %{$comic->{meta_data}->{series}}) {
            foreach my $series ($comic->{meta_data}->{series}->{$language}) {
                $series_count{$language}{$series}++;
            }
        }
    }

    foreach my $comic (@comics) {
        next unless (defined($comic->{meta_data}->{series}));
        foreach my $language (keys %{$comic->{meta_data}->{series}}) {
            foreach my $series ($comic->{meta_data}->{series}->{$language}) {
                if ($series_count{$language}{$series} == 1) {
                    $comic->_note("$language has only one comic in the '$series' series");
                }
            }
        }
    }

    return;
}


sub _archive_filter {
    my ($comic, $language) = @ARG;
    return !$comic->not_yet_published() && $comic->_is_for($language);
}


sub _no_language_archive_filter {
    my ($comic) = @ARG;
    return !$comic->not_yet_published();
}


sub _backlog_filter {
    my ($comic) = @ARG;
    return $comic->not_yet_published();
}


sub _do_export_archive {
    my ($archive_templates, $archive_pages) = @ARG;

    foreach my $language (sort keys %{$archive_templates}) {
        my $page = ${$archive_pages}{$language};

        my @filtered = sort _compare grep { _archive_filter($_, $language) } @comics;
        if (!@filtered) {
            _write_file($page, '<p>No comics in archive.</p>');
            next;
        }

        my %vars;
        $vars{'root'} = '';
        $vars{'comics'} = \@filtered;
        $vars{'modified'} = $filtered[-1]->{modified};
        $vars{'notFor'} = \&_not_for;

        my $templ_file = ${$archive_templates}{$language};
        _write_file($page, _templatize('archive', $templ_file, $language, %vars));
    }

    return;
}


sub _do_export_backlog {
    my ($templ_file, $page, @languages) = @ARG;

    my @filtered = sort _compare grep { _backlog_filter($_) } @comics;
    if (!@filtered) {
        _write_file($page, '<p>No comics in backlog.</p>');
        return;
    }

    my %tags;
    my %who;
    my %series;
    foreach my $comic (@comics) {
        foreach my $language ($comic->_languages()) {
            foreach my $tag (@{$comic->{meta_data}->{tags}->{$language}}) {
                $tags{"$tag ($language)"}++;
            }
            foreach my $who (@{$comic->{meta_data}->{who}->{$language}}) {
                $who{"$who ($language)"}++;
            }
            if ($comic->{meta_data}->{series}) {
                my $serie = $comic->{meta_data}->{series}->{$language};
                $series{"$serie ($language)"}++ if ($serie);
            }
            $comic->{htmlFile}{$language} = lc $language  . "/$comic->{htmlFile}{$language}";
        }
    }

    my %vars;
    $vars{'languages'} = \@languages;
    $vars{'comics'} = \@filtered;
    $vars{'publishers'} = _publishers();
    $vars{'tags'} = \%tags;
    $vars{'who'} = \%who;
    $vars{'series'} = \%series;

    ## no critic(BuiltinFunctions::ProhibitReverseSortBlock)
    # I need to sort by count first, then alphabetically by name, so I have to use
    # $b on the left side of the comparison operator. Perl Critic doesn't understand
    # my sorting needs...
    $vars{'tagsOrder'} = [ sort { $tags{$b} <=> $tags{$a} or $a cmp $b} keys %tags ];
    $vars{'whoOrder'} = [ sort { $who{$b} <=> $who{$a} or $a cmp $b} keys %who ];
    # use critic
    $vars{'seriesOrder'} = [ sort keys %series ];

    _write_file($page, _templatize('backlog', $templ_file, '', %vars));

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

=item B<$what> what counts to get, e.g., "tags" or "who".

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
        -inline => 1,
        -printerror => 1,
        -raiseerror => 1);

    foreach my $comic (sort _compare @comics) {
        my $color = 'green';
        $color = 'blue' if ($comic->not_yet_published());
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
    $vars{svg} = _sort_styles($svg->xmlify());

    _write_file($output, _templatize('size map', $template, '', %vars));

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


sub _sort_styles {
    my ($input) = @ARG;

    my $xml = XML::LibXML->load_xml(string => $input);
    _sort_styles_traverse($xml->documentElement());
    return $xml->toString();
}


sub _sort_styles_traverse {
    my ($node) = @ARG;

    if ($node->{'style'}) {
        $node->{'style'} = join '; ', sort split qr{\s*;\s*}, $node->{'style'};
    }
    foreach my $child ($node->childNodes()) {
        if (ref($child) eq 'XML::LibXML::Element') {
            _sort_styles_traverse($child);
        }
    }
    return;
}


=head2 export_feed

Writes an RSS or Atom feed XML for all comics and each language encountered.

Parameters:

=over 4

=item B<$items> number of comics to include in the feed.

=item B<$toFile> to which file to write the feed, e.g., F<rss.xml>. This
will be within F<generated/web/<language>>.

=item B<%templates> hash of language to RSS template file name.

=back

=cut

sub export_feed {
    my ($items, $to, %templates) = @ARG;

    my $now = _now();
    $now->set_time_zone(_get_tz());
    $now = DateTime::Format::RFC3339->new()->format_datetime($now);

    foreach my $language (keys %templates) {
        my %vars = (
            'comics' => [reverse sort _compare grep { _archive_filter($_, $language) } @comics],
            'notFor' => \&_not_for,
            'max' => $items,
            'updated' => $now,
        );
        my $feed =_templatize('(none)', $templates{$language}, $language, %vars);
        _write_file('generated/web/' . lc($language) . "/$to", $feed);
    }
    return;
}


sub _croak {
    my ($self, $msg) = @ARG;
    croak "$self->{srcFile} : $msg";
}


sub _warn {
    my ($self, $msg) = @ARG;

    $self->_croak($msg) unless ($self->not_yet_published());
    $self->_note($msg);
    return;
}


sub _note {
    my ($self, $msg) = @ARG;

    # Warnings can be duplicated if language-independent code is called in a
    # per-language loop for simplicity. Ignore those.
    # PerlCritic doesn't see that the code below is array access.
    ## no critic(ValuesAndExpressions::ProhibitMagicNumbers)
    return if (@{$self->{warnings}} && ${$self->{warnings}}[-1] eq $msg);
    ## use critic
    push @{$self->{warnings}}, $msg;
    # PerlCritic wants me to check that I/O to the console worked.
    ## no critic(InputOutput::RequireCheckedSyscalls)
    print "$msg\n";
    ## use critic
    return;
}


=head2 post_to_social_media

Posts the latest comic on social media.

Will not post a comic if it isn't scheduled for today, to avoid not having a
comic and then blasting out the post for previous week's comic.

Parameters:

=over 4

=item B<mode> png or html to decide whether to post the PNG file directly
or rather the link to the comic's page.

=item B<@languages> for which languages to promote the last comic. If not
given, the comic is tweeted for all languages that have a meta data twitter
entry.

=back

Returns log information (usually the URLs posted to and such) if successful,
or croaks if no current comic was found or the last comic isn't from today.

=cut

sub post_to_social_media {
    my %settings = @ARG;

    my $posted = 0;
    my $log;
    my @published = reverse sort _compare grep { _no_language_archive_filter($_) } @comics;
    foreach my $comic (@published) {
        # Sorting is by date first, so it's safe to exit the loop at the first
        # comic that's not up to date.
        last if ($comic->_is_not_current());
        foreach my $language (sort keys %{$comic->{meta_data}->{title}}) {
            # Twitter
            $log .= _tweet($comic, $language, %{$settings{'twitter'}}) . "\n";

            # Global default subredit
            my $use_default = $comic->{meta_data}->{reddit}->{'use-default'} // 1;
            if ($use_default) {
                $log .= _reddit($comic, $language, %{$settings{'reddit'}}) . "\n";
            }

            # Subreddits specified in the comic
            foreach my $s ($comic->_get_subreddits($language)) {
                if ($s) {
                    my %options = %{$settings{'reddit'}};
                    if (defined($comic->{meta_data}->{reddit}->{$language})) {
                        %options = (%options, %{$comic->{meta_data}->{reddit}->{$language}});
                    }
                    $options{'subreddit'} = $s;
                    $log .= _reddit($comic, $language, %options) . "\n";
                }
            }

            $posted = 1;
        }
    }
    if (!$posted) {
        my $latest = $published[0];
        $latest->_croak("Not posting cause latest comic is not current ($latest->{meta_data}->{published}->{when})");
    }
    return $log;
}


sub _get_subreddits {
    my ($self, $language) = @ARG;

    my @subreddits;
    my $json = $self->{meta_data}->{reddit}->{$language}->{subreddit};
    if (defined $json) {
        if (ref($json) eq 'ARRAY') {
            push @subreddits, @{$json};
        }
        else {
            push @subreddits, $json;
        }
    }
    return @subreddits;
}


sub _is_not_current {
    my ($self) = @ARG;

    my $today = _now();
    $today->set_time_zone(_get_tz());
    my $published = $self->{meta_data}->{published}->{when} || $UNPUBLISHED;
    return ($published cmp $today->ymd) < 0;
}


sub _tweet {
    my ($comic, $language, %twitter_settings) = @_;

    my %settings = (
        mode => 'png',
        traits => [qw/API::RESTv1_1/],
        ssl => 1,
        %twitter_settings,
    );

    unless ($settings{'mode'} eq 'png' || $settings{'mode'} eq 'html') {
        croak("Unknown twitter mode '$settings{'mode'}'");
    }

    my $description = $comic->{meta_data}->{description}->{$language};
    my $tags = '';
    if ($comic->{meta_data}->{twitter}->{$language}) {
        $tags = join(' ', @{$comic->{meta_data}->{twitter}->{$language}}) . ' ';
    }
    my $text = _shorten_for_twitter("$tags$description");

    my $twitter = Net::Twitter->new(%settings);
    my $status;
    if ($settings{'mode'} eq 'html') {
        $status = $twitter->update($comic->{url}{$language});
    }
    else {
        $status = $twitter->update_with_media($text, [
            "$comic->{whereTo}{$language}/$comic->{pngFile}{$language}"
        ]);
    }

    if (my $err = $EVAL_ERROR) {
        croak $err unless blessed $status && $status->isa('Net::Twitter::Error');
        croak $err->code, ': ', $err->message, "\n", $err->error, "\n";
    }
    return $status->{text};
}


sub _shorten_for_twitter {
    my $text = shift;

    Readonly my $MAX_LEN => 280;
    return substr $text, 0, $MAX_LEN;
}


sub _reddit {
    # Account must not have 2FA enabled!
    my ($comic, $language, %reddit_settings) = @ARG;

    my %settings = (
        subreddit => 'comics',
        user_agent => 'comicupload using Reddit::Client',
        %reddit_settings,
    );

    my $title = "[OC] $comic->{meta_data}->{title}{$language}";
    # https://redditclient.readthedocs.io/en/latest/oauth/
    my $reddit = Reddit::Client->new(%settings);
    my $subreddit = $settings{'subreddit'};
    # Remove leading /r/ and trailing / to make specifiying the subreddit more
    # lenient / user friendly.
    $subreddit =~ s{^/r/}{};
    $subreddit =~ s{/$}{};
    my $message;
    my $full_name = 0;
    while (!$full_name) {
        eval {
            $full_name = $reddit->submit_link(
                subreddit => $subreddit,
                title => $title,
                url => $comic->{url}{$language},
            );
        }
        or do {
            $message = $comic->_wait_for_reddit_limit($EVAL_ERROR);
            last if (defined $message);
        }
    }

    if ($message) {
        return "$language: /r/$subreddit: $message";
    }

    $message = "Posted '$title' ($comic->{url}{$language}) to $subreddit";
    if ($full_name) {
        $message .= " ($full_name) at " . $reddit->get_link($full_name)->{permalink};
    }
    return $message;
}


sub _wait_for_reddit_limit {
    my ($self, $error) = @ARG;

    if ($error =~ m{\btry again in (\d+) (minutes?|seconds?)}i) {
        my ($count, $unit) = ($1, $2);
        if ($unit =~ m/minutes?/i) {
            Readonly my $SECS_PER_MINUTE => 60;
            $count *= $SECS_PER_MINUTE;
        }
        _sleep($count);
    }
    elsif ($error =~ m/ALREADY_SUB/) {
        chomp $error;
        return $error;
    }
    elsif ($error) {
        $self->_croak("Don't know what reddit complains about: '$error'");
    }

    return '';
}


sub _sleep {
    sleep @ARG;
    return;
}


1;


=head1 DIAGNOSTICS

None.


=head1 DEPENDENCIES

Inkscape 0.91 or later.


=head1 CONFIGURATION AND ENVIRONMENT

The inkscape binary must be in the current $PATH.

On Linux, Inkscape needs an active dbus session to export files.


=head1 INCOMPATIBILITIES

None known.


=head1 BUGS AND LIMITATIONS

Works only with Inkscape files.

Has only been tested / used on Linux.

No bugs have been reported cause nobody but me uses this.

Please report any bugs or feature requests to C<< <rwenner@cpan.org> >>


=head1 AUTHOR

Robert Wenner  C<< <rwenner@cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 - 2017, Robert Wenner C<< <rwenner@cpan.org> >>.
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
