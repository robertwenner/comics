package Comic;

use strict;
use warnings;

use Readonly;
use English '-no_match_vars';
use utf8;
use Locales unicode => 1;
use base qw(Exporter);
use POSIX qw(strftime floor);
use Carp;
use autodie;
use String::Util 'trim';
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::RFC3339;
use File::Path qw(make_path);
use File::Basename;
use File::Copy;
use File::Slurper;
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use XML::LibXML;
use XML::LibXML::XPathContext;
use JSON;
use HTML::Entities;
use Image::ExifTool qw(:Public);
use Image::SVG::Transform;
use SVG;
use URI::Encode qw(uri_encode uri_decode);
use Clone qw(clone);

use Comic::Consts;
use Comic::Settings;
use Comic::Modules;
use Comic::Check::Check;
use Comic::Out::Template;
use Comic::Social::Twitter;
use Comic::Social::Reddit;


use version; our $VERSION = qv('0.0.3');

=for stopwords inkscape html svg png Wenner merchantability perlartistic MetaEnglish rss sitemap sizemap xml dbus JSON metadata outdir


=head1 NAME

Comic - Converts SVG comics to png by language and creates HTML pages.


=head1 VERSION

This document refers to version 0.0.3.


=head1 SYNOPSIS

    use Comic;
    use Comic::Settings;

    my $settings = Comic::Settings->new();
    foreach my $file (@ARGV) {
        my $c = Comic->new($file, $settings);
        $c->export_png();
    }
    Comic::export_all_html(
        'English' => 'templates/english/comic-page.templ',
        'Deutsch' => 'templates/deutsch/comic-page.templ',
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
    Comic::size_map('templates/sizemap.templ', 'generated/sizemap.html');
    print Comic::post_to_social_media('English');

=head1 DESCRIPTION

From on an Inkscape SVG file, exports language layers to create per language
PNG files. Creates an archive overview page, a backlog page of not yet
published comics, and a sizemap to compare image sizes.

=cut


# XPath default namespace name.
Readonly my $DEFAULT_NAMESPACE => 'defNs';

# What date to use for sorting unpublished comics.
Readonly my $UNPUBLISHED => '3000-01-01';

# Temp dir for caches, per-langugage svg exports, etc.
Readonly my $TEMPDIR => 'tmp';


my %counts;
my %language_code_cache;
# @todo get rid of @comics
my @comics;
## no critic(Variables::ProhibitPackageVars)
our $inkscape_version;
## use critic


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic from an Inkscape SVG file.

Parameters:

=over 4

=item * B<$path/file> path and file name to the SVG input file.

=item * B<$settings> Comic::Settings object with settings for all comics.

=back

=cut

sub new {
    my ($class, $file, $settings) = @ARG;
    my $self = bless{}, $class;

    $self->{settings} = $settings;
    if ($settings->{$Comic::Settings::CHECKS}) {
        @{$self->{checks}} = @{$settings->{$Comic::Settings::CHECKS}};
    }
    else {
        @{$self->{checks}} = ();
    }

    if ($settings->{$Comic::Settings::GENERATORS}) {
        @{$self->{generators}} = @{$settings->{$Comic::Settings::GENERATORS}};
    }
    else {
        @{$self->{generators}} = ();
    }

    $self->_load($file);
    $self->_adjust_checks($self->{meta_data}->{$Comic::Settings::CHECKS});

    return $self;
}


=head2 _adjust_checks

Adjusts the checks on a per-comic basis. Each comic will normally use the
default checks. Comics can modify these defaults by defining a C<Checks>
entry in their metadata.

That C<Checks> needs to be a JSON array containing any of these keywords as
objects (case-sensitive):

=over 4

=item * B<use> Use only the given Checks for this Comic, ignore the main
    configuration's checks completely. This can be used if the Comic has
    completely different Check needs than all the other comics.

=item * B<add> Add the given Checks to the ones from the main configuration.
    This is helpful if this Comic needs a Check that others don't need.
    If there was already a Check by that type, it's replaced with the new
    one.

=item * B<remove> Remove the given Checks from the configured Checks. This is
    useful if a Check that's helpful for most other Comics doesn't make
    sense for this one.

=back

These keywords are evaluated in the order they appear in the Comic metadata.
You should probably only either use C<use> or a combination of C<add> and
C<remove> anyway.

For example, assuming the main configuration says to use the Checks
F<Comic::Check::Weekday> and F<Comic::Check::Tags> (checking for "Tags" and
"Who").

The following per-comic configuration will replace these checks with only a
C<Comic::Check::Actors> Check. No arguments are passed to
C<Comic::Check::Actor> so it will use whatever defaults it has.

    {
        "Check": {
            "use": [
                "Comic::Check::Actors"
            ]
        }
    }

If the Check takes arguments, they can be passed as well, but the the new
Checks need to be given as an object instead of an array, like in this
example:

    {
        "Check": {
            "use": {
                "Comic::Check::Weekday": [1]
            }
        }
    }

With the same base configuration, this will remove the weekday check. This
configuration could be used for a one-off comic:

    {
        "Check": {
            "remove": [ "Comic::Check::Weekday" ]
        }
    }

This example would go one step further and redefine the tags to check (to
only check "Tag", but not "Who" as in the base configuration, for a comic
without people), and add a Date collision check for this Comic:

    {
        "Check": {
            "add": {
                "Comic::Check::Tag": ["tags"]
                "Comic::Check::DateCollision"
            ]
        }
    }

=cut

sub _adjust_checks {
    my ($self, $check_config) = @ARG;

    return if (!$check_config);

    foreach my $keyword (keys %{$check_config}) {
        if ($keyword eq 'use') {
            @{$self->{checks}} = ();
            $self->_add_checks($check_config->{'use'});
        }

        elsif ($keyword eq 'add') {
            my $adding = $check_config->{'add'};
            $self->_remove_checks($adding);
            $self->_add_checks($adding);
        }

        elsif ($keyword eq 'remove') {
            my $removing = $check_config->{'remove'};
            if (ref $removing ne ref []) {
                $self->keel_over('Must pass an array to "remove"');
            }
            $self->_remove_checks($removing);
        }

        else {
            $self->keel_over("Unknown Check option $keyword; use one of use, add, or remove");
        }
    }

    return;
}


# Converts an array ref to a hash ref (with elements pointing to empty array
# references) to easily add Checks without arguments (where the Check then
# falls back on default arguments). If the passed reference is already a
# hash reference, return it.
sub _array_ref_to_hash_ref {
    my ($array_or_hash_ref) = @ARG;

    if (ref $array_or_hash_ref eq ref []) {
        $array_or_hash_ref = { map { $_ => [] } @{$array_or_hash_ref} };
    }

    return $array_or_hash_ref;
}


# Creates and adds the Checks for the given module names to this comic.
sub _add_checks {
    my ($self, $checks) = @ARG;

    $checks = _array_ref_to_hash_ref($checks);
    foreach my $name (keys %{$checks}) {
        Comic::Modules::load_module($self->{checks}, $name, ${$checks}{$name} || []);
    }

    return;
}


# Removes the given check types from this Comic.
sub _remove_checks {
    my ($self, $checks) = @ARG;

    $checks = _array_ref_to_hash_ref($checks);
    foreach my $name (keys %{$checks}) {
        @{$self->{checks}} = grep { ref $_ ne Comic::Modules::module_name($name) } @{$self->{checks}};
    }

    return;
}


sub _load {
    my ($self, $file) = @ARG;

    $self->{srcFile} = $file;
    $self->{warnings} = [];
    my $meta_data;
    my $meta_cache = _meta_cache_for($self->{srcFile});
    $self->{use_meta_data_cache} = _up_to_date($self->{srcFile}, $meta_cache);
    if ($self->{use_meta_data_cache}) {
        $meta_data = File::Slurper::read_text($meta_cache);
    }
    else {
        $self->{dom} = _parse_xml(File::Slurper::read_text($file));
        $self->{xpath} = XML::LibXML::XPathContext->new($self->{dom});
        $self->{xpath}->registerNs($DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
        my $meta_xpath = _build_xpath('metadata/rdf:RDF/cc:Work/dc:description/text()');
        $meta_data = _unhtml(join ' ', $self->{xpath}->findnodes($meta_xpath));
    }
    eval {
        $self->{meta_data} = from_json($meta_data);
    } or $self->keel_over("Error in JSON for: $EVAL_ERROR");
    if (!$self->{use_meta_data_cache}) {
        write_file($meta_cache, $meta_data);
    }

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
    foreach my $language ($self->languages()) {
        my $domain = ${$self->{settings}->{Domains}}{$language};
        $self->keel_over("No domain for $language") unless ($domain);

        $self->{backlogPath}{$language} = 'generated/backlog/' . lc $language;
        my $base;
        if ($self->not_yet_published()) {
            $base = $self->{backlogPath}{$language};
        }
        else {
            $base = 'web/' . lc $language . '/comics';
        }

        $self->{titleUrlEncoded}{$language} = uri_encode($self->{meta_data}->{title}->{$language}, %uri_encoding_options);
        $self->{whereTo}{$language} = make_dir($base);
        $self->{baseName}{$language} = $self->_normalized_title($language);
        $self->{htmlFile}{$language} = "$self->{baseName}{$language}.html";
        $self->{pngFile}{$language} = "$self->{baseName}{$language}.png";
        $self->{url}{$language} = "https://$domain/comics/$self->{baseName}{$language}.html";
        $self->{urlUrlEncoded}{$language} = uri_encode($self->{url}{$language}, %uri_encoding_options);
        $self->{imageUrl}{$language} = "https://$domain/comics/$self->{baseName}{$language}.png";
        $self->{href}{$language} = "comics/$self->{htmlFile}{$language}";

        $counts{'comics'}{$language}++;
    }

    push @comics, $self;
    $self->_count_tags();
    return;
}


sub _meta_cache_for {
    my ($svg_file) = @ARG;
    return _cache_file_for($svg_file, 'meta', 'json');
}


sub _transcript_cache_for {
    my ($svg_file, $language) = @ARG;
    return _cache_file_for("$language/$svg_file", 'transcript', 'txt');
}


sub _cache_file_for {
    my ($svg_file, $dir, $ext) = @ARG;

    my ($filename, $dirs, $suffix) = fileparse($svg_file);
    if ($dirs eq q{./}) { # no path
        $dirs = '';
    }
    $filename =~ s/\.svg$//;
    return make_dir($TEMPDIR . "/$dir/$dirs") . "$filename.$ext";
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


sub _mtime {
    # uncoverable subroutine
    my ($file) = @ARG; # uncoverable statement

    Readonly my $MTIME => 9; # uncoverable statement
    return (stat $file)[$MTIME]; # uncoverable statement
}


sub _now {
    # uncoverable subroutine
    return DateTime->now; # uncoverable statement
}


sub _get_tz {
    # uncoverable subroutine
    return strftime '%z', localtime; # uncoverable statement
}


=head2 outdir

Returns the output directory where this Comic's output should go. This may
depend on whether the comic is already published and where;

The directory will be created by this method if it doesn't yet exist.

Parameters:

=over 4

=item * B<$comic> for which comic to get the output directory.

=item * B<language> the Comic's language.

=back

=cut

sub outdir {
    my ($self, $language) = @ARG;

    my $outdir;
    if ($self->_not_published_on_the_web($language)) {
        $outdir = 'generated/backlog/';
    }
    else {
        $outdir = 'generated/web/' . lc($language) . q{/};
    }
    return make_dir($outdir);
}


=head2 export_png

Exports PNGs for all languages with meta data in this Comic.

The png file will be the lower case title of the comic, limited to letters,
numbers, and hyphens only. It will be placed in F<generated/web/$language/>.

Inkscape files must have meta data matching layer names, e.g., "English" in
the meta data and an "English" layer and an "MetaEnglish" layer.

=cut

sub export_png {
    my ($self) = @ARG;

    foreach my $language ($self->languages()) {
        my $png_file = "$self->{whereTo}{$language}/$self->{pngFile}{$language}";
        my $backlog_png = "$self->{backlogPath}{$language}/$self->{pngFile}{$language}" || '';

        if (_up_to_date($self->{srcFile}, $backlog_png)) {
            _move($backlog_png, $png_file) or $self->keel_over("Cannot move $backlog_png to $png_file: $OS_ERROR");
        }

        unless (_up_to_date($self->{srcFile}, $png_file)) {
            $self->_flip_language_layers($language);
            my $language_svg = $self->_write_temp_svg_file($language);
            $self->_svg_to_png($language, $language_svg);
        }
        $self->_get_png_info($png_file, $language);
    }
    return;
}


sub _move {
    # uncoverable subroutine
    return File::Copy::move(@ARG); # uncoverable statement
}


=head2 check

Runs all configured checks on this comic. The order in which checks run is
undefined. (Checks should not depend on each other anyway.)

Checks are configured in the main configuration file under the C<Check> key.
This needs to be a JSON object where the key is the name of the Perl module
to use. This name can either be in double colon notation (like a Perl
module's name in a C<use> statement), or as a path relative to a folder in
C<@INC>. The value is an array or hash of values to pass to the check module's
constructor. See the respective check module's documentation for
documentation on the constructor arguments.

The following example configures five checks. The Weekday check gets passed
5, which is Friday, according to the L<Comic::Check::Weekday> documentation.

The L<Comic::Check::DontPublish> check gets passed the tags C<DONT_PUBLISH>
and C<FIXME> to look for.

Finally L<Comic::Check::Frames> uses named parameters in an object. The
names need to match what the module expects or they may be silently ignored.

    {
        "Check": {
            "Comic/Check/Transcript.pm": [],
            "Comic/Check/Actors": [],
            "Comic::Check::DontPublish": [ "DONT_PUBLISH", "FIXME" ],
            "Comic::Check::Weekday.pm", [ 5 ],
            "Comic::Check::Frames": {
                "FRAME_ROW_HEIGHT": 1.25
            }
        }
    }

If no checks are configured, all available (installed) checks are used.
A Perl module is considered a check if it's package name starts with
C<Comic::Check::>.

To disable all checks, configure an empty C<Check>:

    {
        "Check": {}
    }

=cut

sub check {
    my ($self) = @_;

    foreach my $check (@{$self->{checks}}) {
        $check->notify($self);
    }

    return if ($self->{use_meta_data_cache});

    foreach my $check (@{$self->{checks}}) {
        $check->check($self);
    }

    return;
}


=head2 get_transcript

Gets this Comic's transcript. The transcript is ordered text from this
Comic's meta and real text layers, ordered from top left to bottom right by
frames. Usually it consists of speaker indicators and actual speech texts,
plus maybe some background texts.

Parameters:

=over 4

=item * B<language> for which language to get the transcript.

=back

=cut

sub get_transcript {
    my ($self, $language) = @ARG;

    if (!defined($self->{transcript}{$language})) {
        my $cache = _transcript_cache_for($self->{srcFile}, $language);
        my $transcript_cached = _up_to_date($self->{srcFile}, $cache);
        if ($transcript_cached) {
            @{$self->{transcript}{$language}} = split /[\r\n]+/, File::Slurper::read_text($cache);
        }
        else {
            @{$self->{transcript}{$language}} = _append_speech_to_speaker($self->texts_in_language($language));
            write_file($cache, join "\n", @{$self->{transcript}{$language}});
        }
    }
    return @{$self->{transcript}{$language}};
}


sub _up_to_date {
    # Takes file names as arguments rather than being a member method for
    # easier mocking.
    my ($source, $target) = @ARG;

    my $up_to_date = 0;
    if (_exists($source) && _exists($target)) {
        my $source_mod = _mtime($source);
        my $target_mod = _mtime($target);
        $up_to_date = $target_mod > $source_mod;
    }
    return $up_to_date;
}


sub _exists {
    # uncoverable subroutine
    return -r shift; # uncoverable statement
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

    if (abs($ya - $yb) < $Comic::Consts::FRAME_ROW_HEIGHT) {
        # If frames are at roughly equal height, they are in the same row, and
        # their x position matters.
        return $xa <=> $xb;
    }
    return $ya <=> $yb;
}


sub _count_tags {
    my ($self) = @ARG;

    foreach my $what ('tags', 'who') {
        next unless ($self->{meta_data}->{$what});
        foreach my $language (keys %{$self->{meta_data}->{$what}}) {
            foreach my $val (@{$self->{meta_data}->{$what}->{$language}}) {
                $val = _normalize_whitespace($val);
                $counts{$what}{$language}{$val}++;
            }
        }
    }
    return;
}


sub _normalize_whitespace {
    my ($val) = @ARG;
    $val = trim($val);
    $val =~ s/\s+/ /g;
    return $val;
}


=head2 get_all_layers

Gets all SVG layers defined in this Comic.

=cut

sub get_all_layers {
    my ($self) = @ARG;

    return $self->{xpath}->findnodes(_find_layers());
}


sub _flip_language_layers {
    my ($self, $language) = @ARG;

    # Hide all but current language layers
    my $had_lang = 0;
    foreach my $layer ($self->{xpath}->findnodes(_find_layers())) {
        my $label = $layer->{'inkscape:label'};
        $layer->{'style'} = 'display:inline' unless (defined($layer->{'style'}));
        foreach my $other_lang ($self->languages()) {
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
        $self->keel_over("no $language layer");
    }
    return;
}


=head2 has_layer

Checks whether this Comic has (all the Inkscape layer(s) by the given name(s).

Parameters:

=over 4

=item * B<layer> For which layer(s) to look.

=back

=cut

sub has_layer {
    my ($self, @layers) = @ARG;

    foreach my $layer (@layers) {
        if (!$self->{xpath}->findnodes($self->_find_layers($layer))) {
            return 0;
        }
    }
    return 1;
}


sub _find_layers {
    # Builds an XPath expression to find the top-level Inkscape layers
    # (i.e., below the svg element) with the given name(s) or all layers if
    # no name is given.
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


sub _write_temp_svg_file {
    my ($self, $language) = @ARG;

    my $temp_file_name = make_dir("$TEMPDIR/" . lc $language . '/svg/') . "$self->{baseName}{$language}.svg";
    my $svg = $self->_copy_svg($language);
    _drop_top_level_layers($svg, 'Raw');
    $self->_insert_url($svg, $language);
    $svg->toFile($temp_file_name);
    return $temp_file_name;
}


sub _copy_svg {
    my ($self) = @ARG;
    return _parse_xml($self->{dom}->toString());
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


sub _insert_url {
    my ($self, $svg, $language) = @ARG;

    my $domain = ${$self->{settings}->{Domains}}{$language};
    my $payload = XML::LibXML::Text->new("$domain — CC BY-NC-SA 4.0");
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
    # uncoverable subroutine
    my ($self, $what) = @ARG; # uncoverable statement
    ## no critic(InputOutput::ProhibitBacktickOperators)
    return `inkscape -$what $self->{srcFile}`; # uncoverable statement
    ## use critic
}


sub _frames_in_rows {
    my @frames = @ARG;
    my $prev = shift @frames;
    foreach my $frame (@frames) {
        my $off_by = $frame->getAttribute('y') - $prev->getAttribute('y');
        if ($off_by < -$Comic::Consts::FRAME_SPACING || $off_by > $Comic::Consts::FRAME_SPACING) {
            return 1;
        }
        $prev = $frame;
    }
    return 0;
}


sub _query_inkscape_version {
    # uncoverable subroutine
    my ($self) = @ARG; # uncoverable statement

    # Inkscape seems to print its plugins information to stderr, e.g.:
    #    Pango version: 1.46.0
    # Hence redirect stderr to /dev/null.

    ## no critic(InputOutput::ProhibitBacktickOperators)
    my $version = `inkscape --version 2>/dev/null`; # uncoverable statement
    ## use critic
    if ($OS_ERROR) { # uncoverable branch true
        $self->keel_over('Could not run Inkscape'); # uncoverable statement
    }
    return $version; # uncoverable statement
}


sub _parse_inkscape_version {
    my ($self, $inkscape_output) = @ARG;

    # Inkscape 0.92.5 (2060ec1f9f, 2020-04-08)
    # Inkscape 1.0 (4035a4fb49, 2020-05-01)
    if ($inkscape_output =~ m/^Inkscape\s+(\d\.\d)/) {
        return $1;
    }
    $self->keel_over("Cannot figure out Inkscape version from this:\n$inkscape_output");
    # PerlCritic doesn't know that keel_over doesn't return and the return statement
    # here is unreachable.
    return 'unknown';
}


sub _get_inkscape_version {
    my ($self) = @ARG;

    unless (defined $inkscape_version) {
        $inkscape_version = $self->_parse_inkscape_version($self->_query_inkscape_version());
    }
    return $inkscape_version;
}


sub _build_inkscape_command {
    my ($self, $svg_file, $png_file, $version) = @ARG;

    if ($version eq '0.9') {
        return 'inkscape --g-fatal-warnings --without-gui ' .
            "--file=$svg_file --export-png=$png_file " .
            '--export-area-drawing --export-background=#ffffff';
    }
    if ($version ne '1.0') {
        $self->_warn("Don't know Inkscape $version, hoping it's compatible to 1.0");
    }

    return 'inkscape --g-fatal-warnings ' .
        "--export-type=png --export-filename=$png_file " .
        "--export-area-drawing --export-background=#ffffff $svg_file";
}


sub _svg_to_png {
    my ($self, $language, $svg_file) = @ARG;

    my $png_file = "$self->{whereTo}{$language}/$self->{pngFile}{$language}";
    my $version = $self->_get_inkscape_version();
    my $export_cmd = $self->_build_inkscape_command($svg_file, $png_file, $version);
    _system($export_cmd) && $self->keel_over("could not export: $export_cmd: $OS_ERROR");

    my $tool = Image::ExifTool->new();
    # Add data inferred from comic
    my %meta_data = (
        'Title' => $self->{meta_data}->{title}->{$language},
        'Description' => join('', $self->get_transcript($language)),
        'CreationTime' => $self->{modified},
        'URL' => $self->{url}{$language},
    );
    foreach my $m (keys %meta_data) {
        $self->_set_png_meta($tool, $m, $meta_data{$m});
    }
    # Add global settings
    my %settings = %{$self->{settings}};
    foreach my $key (qw/Author Artist Copyright/) {
        if ($settings{$key}) {
            $self->_set_png_meta($tool, $key, $settings{$key});
        }
    }
    # Add data explicitly overriden in comic meta data
    my $svg_meta = $self->{meta_data}->{'png-meta-data'};
    if (ref($svg_meta) eq 'HASH') {
        foreach my $key (keys %{$svg_meta}) {
            $self->_set_png_meta($tool, $key, ${${svg_meta}}{$key});
        }
    }
    # Finally write png meta data
    my $rc = $tool->WriteInfo($png_file);
    if ($rc != 1) {
        $self->keel_over('cannot write PNG meta data: ' . $tool->GetValue('Error'));
    }

    # Shrink / optimize PNG
    my $shrink_cmd = "optipng --quiet $png_file";
    _system($shrink_cmd) && $self->keel_over("Could not shrink: $shrink_cmd: $OS_ERROR");

    return;
}


sub _system {
    # uncoverable subroutine
    return system @ARG; # uncoverable statement
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
    $self->keel_over("Cannot set $name: $error") if ($error);
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
    # uncoverable subroutine
    my ($name) = @_; # uncoverable statement

    Readonly my $SIZE => 7; # uncoverable statement
    return (stat $name)[$SIZE]; # uncoverable statement
}


=head2 make_dir

Create given directory if it doesn't exist yet.

Parameters:

=over 4

=item * B<$dir> directory to create.

=back

=cut

sub make_dir {
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
    $self->keel_over("No $language title in $self->{srcFile}") unless($title);
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

Parameters:

=over 4

=item * B<%templates> hash of language to path / file name of the comic page
    templates.

=back

=cut

sub export_all_html {
    # @todo move template into config
    my %templates = @ARG;

    my @sorted = sort from_oldest_to_latest @comics;
    foreach my $i (0 .. @sorted - 1) {
        my $comic = $sorted[$i];

        foreach my $language ($comic->languages()) {
            my $first_comic = _find_next($language, $i, \@sorted, [0 .. $i - 1]);
            $comic->{'first'}{$language} = $first_comic ? $first_comic->{htmlFile}{$language} : 0;
            my $prev_comic = _find_next($language, $i, \@sorted, [reverse 0 .. $i - 1]);
            $comic->{'prev'}{$language} = $prev_comic ? $prev_comic->{htmlFile}{$language} : 0;
            my $next_comic = _find_next($language, $i, \@sorted, [$i + 1 .. @sorted - 1]);
            $comic->{'next'}{$language} = $next_comic ? $next_comic->{htmlFile}{$language} : 0;
            my $last_comic = _find_next($language, $i, \@sorted, [reverse $i + 1 .. @sorted - 1]);
            $comic->{'last'}{$language} = $last_comic ? $last_comic->{htmlFile}{$language} : 0;
            $comic->_export_language_html($language, $templates{$language});

            make_dir('web/' . lc $language);
        }
    }

    return;
}


sub _all_comic_languages {
    my (@all_comics) = @ARG;

    my %languages;
    foreach my $c (@all_comics) {
        foreach my $language ($c->languages()) {
            $languages{$language} = 1;
        }
    }
    return keys %languages;
}


=head2 export_sitemap

Generates a sitemap per language seen in all comics.

Parameters:

=over 4

=item * B<%site_map_templates> hash of language to path / file name of the
sitemap templates.

=item * B<%outputs> hash of language to path / file name of the generated
sitemaps.

=back

=cut

sub export_sitemap {
    # @todo move templates and output paths into config
    my ($site_map_templates, $outputs, @all_comics) = @_;

    my @sorted = sort from_oldest_to_latest @all_comics;
    my %vars;
    $vars{'comics'} = [ @sorted ];
    $vars{'notFor'} = \&_not_published_on_the_web;
    foreach my $language (_all_comic_languages(@all_comics)) {
        my $templ = ${$site_map_templates}{$language};
        my $xml = Comic::Out::Template::templatize('(none)', $templ, $language, %vars);
        write_file(${$outputs}{$language}, $xml);
    }

    return;
}


=head2 languages

Gets an alphabetically sorted array of all languages used in this Comic.

=cut

sub languages {
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


sub _find_next {
    my ($language, $pos, $comics, $nums) = @_;

    foreach my $i (@{$nums}) {
        next if (@{$comics}[$i]->not_for($language));
        if (@{$comics}[$i]->not_yet_published() == @{$comics}[$pos]->not_yet_published()) {
            return @{$comics}[$i];
        }

    }
    return 0;
}


sub _export_language_html {
    my ($self, $language, $template) = @ARG;

    $self->get_transcript($language);
    write_file("$self->{whereTo}{$language}/$self->{htmlFile}{$language}",
        $self->_do_export_html($language, $template));
    return 0;
}


=head2 not_for

Checks whether this Comic is for the given language. A Comic is considered
for a language if it has a title for that language in its  meta data.

Parameters:

=over 4

=item * B<$language> name of language to to check, as spelled in the Comic
    meta data.

=back

=cut

sub not_for {
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
    # TODO passed to a template, should probably be documented.
    my ($self, $language) = @ARG;
    return !$self->_is_for($language) || $self->not_yet_published();
}


sub _do_export_html {
    my ($self, $language, $template) = @ARG;

    # Provide empty tags and who data, if the comic doesn't have that.
    # This avoids a crash in the template when it cannot access these.
    # This should probably be configurable.
    foreach my $what (qw(tags who)) {
        if (!defined $self->{meta_data}->{who}->{$language}) {
            @{$self->{meta_data}->{who}->{$language}} = ();
        }
    }

    my %vars;
    $vars{'comic'} = $self;
    $vars{'languages'} = [grep { $_ ne $language } $self->languages()];
    $vars{'languagecodes'} = { $self->language_codes() };
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
        # If this variable is set, we're called from export_index.
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

    return Comic::Out::Template::templatize($self->{srcFile}, $template, $language, %vars);
}


=head2 language_codes

Gets a hash of language to the international language code for all languages
used in this Comic.

=cut

sub language_codes {
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
        $self->keel_over("cannot find language code for '$lang'");
    }
    return %codes;
}


=head2 texts_in_language

Gets the normalized texts for the given language.

Normalized means line breaks are removed and multiple consecutive spaces are
reduced to one.

Parameters:

=over 4

=item * B<language> Language name(s).

=back

=cut

sub texts_in_language {
    my ($self, @languages) = @ARG;

    $self->_find_frames();
    my @texts;
    foreach my $language (@languages) {
        my @layers = _find_layers($language, "Meta$language", "HintergrundText$language") . "//$DEFAULT_NAMESPACE:text";
        my @nodes = $self->{xpath}->findnodes(@layers);
        foreach my $node (sort { $self->_text_pos_sort($a, $b) } @nodes) {
            push @texts, _text_content($node);
        }
    }
    return @texts;
}


=head2 texts_in_layer

Gets the normalized texts in the given layers.

Normalized means line breaks are removed and multiple consecutive spaces are
reduced to one.

Parameters:

=over 4

=item * B<layer> Inkscape layer name(s) from which to collect texts.

=back

=cut

sub texts_in_layer {
    my ($self, @layers) = @ARG;

    $self->_find_frames();
    my @texts;
    foreach my $layer (@layers) {
        my @layernames = _find_layers($layer) . "//$DEFAULT_NAMESPACE:text";
        my @nodes = $self->{xpath}->findnodes(@layernames);
        foreach my $node (sort { $self->_text_pos_sort($a, $b) } @nodes) {
            push @texts, _text_content($node);
        }
    }
    return @texts;
}


sub _text_content {
    # Inkscape has a <text> for the whole text block, and within that a
    # <tspan> for each line. This function returns all these tspans
    # together. It also cleans up whitespace (replaces line breaks with
    # spaces, replaces multiple spaces with one, and trims).
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
    # Assume frames that have their top within a certain frame tolerance
    # distance from each other are meant to be at the same x or y position,
    # respectively.
    my @frame_tops;
    foreach my $f ($self->_all_frames_sorted()) {
        my $y = floor($f->getAttribute('y'));
        my $found = 0;
        foreach my $ff (@frame_tops) {
            $found = 1 if ($ff + $Comic::Consts::FRAME_TOLERANCE > $y && $ff - $Comic::Consts::FRAME_TOLERANCE < $y);
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
    $self->keel_over('no x') unless(defined $x);
    $self->keel_over('no y') unless(defined $y);

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
    $self->keel_over('No X/Y and no textPath child element') if (@text_path == 0);
    $self->keel_over('No X/Y and multiple textPath child elements') if (@text_path > 1);
    my $path_id = $text_path[0]->getAttribute('xlink:href');
    $path_id =~ s{^#}{};
    my $xpath = "//$DEFAULT_NAMESPACE:ellipse[\@id='$path_id']";
    my @path_nodes = $self->{xpath}->findnodes($xpath);
    $self->keel_over("$xpath not found") if (@path_nodes == 0);
    $self->keel_over("More than one node with ID $path_id") if (@path_nodes > 1);
    my $type = $path_nodes[0]->nodeName;
    $self->keel_over("Cannot handle $type nodes") unless ($type eq 'ellipse');
    return ($path_nodes[0]->getAttribute('cx'), $path_nodes[0]->getAttribute('cy'));
}


sub _pos_to_frame {
    my ($self, $y) = @ARG;

    for my $i (0..@{$self->{frame_tops}} - 1) {
        return $i if ($y < @{$self->{frame_tops}}[$i]);
    }
    return @{$self->{frame_tops}};
}


sub _bottom_right {
    my ($self) = @ARG;

    my @frames = $self->_all_frames_sorted();
    my $bottom_right = $frames[-1];
    # from 0/0, x increases to right, y increases to the bottom
    return ($bottom_right->getAttribute('x') + $bottom_right->getAttribute('width'),
        $bottom_right->getAttribute('y'));
}


=head2 write_file

Writes a file and croaks on errors. All in one place to easily mock file
writing in tests.

Parameters:

=over 4

=item * B<$file_name> path and name of the file to write.

=item * B<contents> what to write.

=back

=cut

sub write_file {
    my ($file_name, $contents) = @ARG;

    open my $F, '>', $file_name or croak "Cannot open $file_name: $OS_ERROR";
    print {$F} $contents or croak "Cannot write to $file_name: $OS_ERROR";
    close $F or croak "Cannot close $file_name: $OS_ERROR";
    return;
}


=head2 export_index

Generates an C<index.html> page for the latest comic in each language.

The file will always be C<web/<language>/index.html>, for example, for
English comics in C<web/english/index.html>.

Parameters:

=over 4

=item * B<%templates> reference to a hash of language to index page template
    file. Depending on your setup, these template files could be just the
    regular comic page template.

=back

=cut

sub export_index {
    my ($templates) = @ARG;

    foreach my $language (sort keys %{$templates}) {
        my $dir = make_dir('generated/web/' . lc $language);
        my @sorted = (sort from_oldest_to_latest grep {
            !$_->not_yet_published($_) && $_->_is_for($language)
        } @comics);
        next if (@sorted == 0);

        my $last_pub = $sorted[-1];
        $last_pub->{isLatestPublished} = 1;
        my $page = "$dir/index.html";
        write_file($page, $last_pub->_do_export_html($language, ${$templates}{$language}));
    }
    return;
}


=head2 export_backlog

Generates a single html page with all unpublished comics plus information on
used tags, series, and characters.

The backlog is language-independent, i.e., all languages are included in the
same backlog page.

Parameters:

=over 4

=item * B<$backlog_template> path / file name of the template file.

=item * B<$backlog_page> path / file name of the generated backlog html.

=back

=cut

sub export_backlog {
    my ($templ_file, $page) = @ARG;

    my @unpublished = sort from_oldest_to_latest grep {
         $_->not_yet_published()
    } @comics;
    if (!@unpublished) {
        write_file($page, '<p>No comics in backlog.</p>');
        return;
    }

    my %tags;
    my %who;
    my %series;
    my %languages;
    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $languages{$language} = 1;
            foreach my $tag (@{$comic->{meta_data}->{tags}->{$language}}) {
                $tag = _normalize_whitespace($tag);
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

    my @languages = sort keys %languages;
    my %vars;
    $vars{'languages'} = \@languages;
    $vars{'comics'} = \@unpublished;
    $vars{'publishers'} = _publishers();
    $vars{'tags'} = \%tags;
    $vars{'who'} = \%who;
    $vars{'series'} = \%series;

    ## no critic(BuiltinFunctions::ProhibitReverseSortBlock)
    # I need to sort by count first, then alphabetically by name, so I have to use
    # $b on the left side of the comparison operator. Perl Critic doesn't understand
    # my sorting needs...
    $vars{'tagsOrder'} = [ sort {
        # First, sort by count
        $tags{$b} <=> $tags{$a} or
        # then by name, case insensitive, so that e.g., m and M get sorted together
        lc $a cmp lc $b or
        # then by name, case sensitive, to avoid names "jumping" around (and breaking tests).
        $a cmp $b
    } keys %tags ];
    $vars{'whoOrder'} = [ sort {
        $who{$b} <=> $who{$a} or
        lc $a cmp lc $b or
        $a cmp $b
    } keys %who ];
    # use critic
    $vars{'seriesOrder'} = [ sort {
        lc $a cmp lc $b or
        $a cmp $b
    } keys %series ];

    write_file($page, Comic::Out::Template::templatize('backlog', $templ_file, '', %vars));

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


=head2 from_oldest_to_latest

Sorts the given comics chronologically from oldest to newest.

For use with Perl's C<sort> function.

=cut

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
sub from_oldest_to_latest($$) {
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
    $inkscape_version = undef;
    return;
}


=head2 counts_of_in

Returns the counts of all 'what' in the given language.
This can be used for a tag cloud.

Parameters:

=over 4

=item * B<$what> what counts to get, e.g., "tags" or "who".

=item * B<$language> for what language, e.g., "English".

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

=item * B<$template> path / file name of the template file.

=item * B<$language> path / file name of the generated sizemap.

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

    foreach my $comic (sort from_oldest_to_latest @comics) {
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

    write_file($output, Comic::Out::Template::templatize('size map', $template, '', %vars));

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


=head2 keel_over

Croak with current comic source file name and given error message.

Parameters:

=over 4

=item * B<message> error message.

=back

=cut

sub keel_over {
    my ($self, $message) = @ARG;
    croak "$self->{srcFile} : $message";
}


sub _warn {
    my ($self, $msg) = @ARG;

    $self->keel_over($msg) unless ($self->not_yet_published());
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
    print {*STDOUT} "$self->{srcFile} : $msg\n";
    ## use critic
    return;
}


=head2 post_to_social_media

Posts the latest comic on social media.

Will not post a comic if it isn't scheduled for today, to avoid not having a
comic and then blasting out the post for previous week's comic.

Parameters:

=over 4

=item * B<mode> png or html to decide whether to post the PNG file directly
    or rather the link to the comic's page.

=back

Returns log information (usually the URLs posted to and such) if successful,
or keel over if no current comic was found or the last comic isn't from today.

=cut

sub post_to_social_media {
    my %settings = @ARG;

    my $twitter = Comic::Social::Twitter->new(%{$settings{'twitter'}});
    my $reddit = Comic::Social::Reddit->new(%{$settings{'reddit'}});

    my $posted = 0;
    my $log;
    my @published = reverse sort from_oldest_to_latest grep {
        !$_->not_yet_published($_)
    } @comics;
    foreach my $comic (@published) {
        # Sorting is by date first, so it's safe to exit the loop at the first
        # comic that's not up to date. This allows to post multiple comics with
        # the same date, when the comics for a day couldn't be translated and
        # there are separate ones per language.
        last if ($comic->_is_not_current());

        $log .= $twitter->tweet($comic) . "\n";
        $log .= $reddit->post($comic) . "\n";
        $posted = 1;
    }
    if (!$posted) {
        my $latest = $published[0];
        $latest->keel_over("Not posting cause latest comic is not current ($latest->{meta_data}->{published}->{when})");
    }
    return $log;
}


sub _is_not_current {
    my ($self) = @ARG;

    my $today = _now();
    $today->set_time_zone(_get_tz());
    my $published = $self->{meta_data}->{published}->{when} || $UNPUBLISHED;
    return ($published cmp $today->ymd) < 0;
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

Copyright (c) 2015 - 2021, Robert Wenner C<< <rwenner@cpan.org> >>.
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
