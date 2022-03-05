package Comic;

use strict;
use warnings;
use utf8;
use autodie;

use Readonly;
use English '-no_match_vars';
use Locales unicode => 1;
use base qw(Exporter);
use POSIX qw(strftime floor);
use Carp;
use autodie;
use String::Util 'trim';
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::RFC3339;
use File::Path;
use File::Basename;
use File::Slurper;
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use XML::LibXML;
use XML::LibXML::XPathContext;
use JSON;
use HTML::Entities;
use Image::ExifTool qw(:Public);
use Image::SVG::Transform;
use URI::Encode qw(uri_encode);

use Comic::Consts;
use Comic::Settings;
use Comic::Modules;


use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords inkscape html svg png Wenner merchantability perlartistic xml dbus outdir JSON metadata

=head1 NAME

Comic - A web comic / cartoon in multiple languages.


=head1 VERSION

This document refers to version 0.0.3.


=head1 SYNOPSIS

    use Comic;
    use Comic::Settings;

    my $settings = Comic::Settings->new();
    foreach my $file (@ARGV) {
        my $c = Comic->new($file, $settings);
    }


=head1 DESCRIPTION

Reads a comic as an Inkscape SVG file and serves as a value object for the comic.

=cut


# XPath default namespace name.
Readonly my $DEFAULT_NAMESPACE => 'defNs';

# What date to use for sorting unpublished comics.
Readonly my $UNPUBLISHED => '3000-01-01';


my %language_code_cache;


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic.

Parameters:

=over 4

=item * B<$settings> Comic::Settings object with settings for all comics.

=item * B<$checks> Array reference of globally configured and loaded checks.
    These are actual C<Comic::Check::Check> instances.

=back

=cut

sub new {
    my ($class, $settings, $checks) = @ARG;
    my $self = bless{}, $class;

    $self->{settings} = $settings;
    $self->{checks} = [@{$checks}];
    $self->{warnings} = [];

    return $self;
}


=head2 load

Loads a comic from a given Inkscape F<.svg> file.

Parameters:

=over 4

=item * B<$file> from which file to load.

=back

=cut

sub load {
    my ($self, $file) = @ARG;

    $self->{srcFile} = $file;

    $self->{dom} = _parse_xml(File::Slurper::read_text($file));
    $self->{xpath} = XML::LibXML::XPathContext->new($self->{dom});
    $self->{xpath}->registerNs($DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $meta_xpath = _build_xpath('metadata/rdf:RDF/cc:Work/dc:description/text()');
    my $meta_data = _unhtml(join ' ', $self->{xpath}->findnodes($meta_xpath));
    eval {
        $self->{meta_data} = from_json($meta_data);
    } or $self->keel_over("Error in JSON for: $EVAL_ERROR");

    # modified is used in <meta name="last-modified" content="..."/> and sitemap.xml
    # Does it need to be in RFC3339 format like that HTTP header?
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Last-Modified
    # Or is that HTML tag obsolete anyway?
    my $modified = DateTime->from_epoch(epoch => _mtime($file));
    $modified->set_time_zone(_get_tz());
    $self->{modified} = $modified->ymd;
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
        $self->{dirName}{$language} = make_dir($base);
        $self->{baseName}{$language} = $self->_normalized_title($language);

        # OLD_CODE_WORKAROUND: Remove this when the templates don't use the
        # whole value (e.g., URL), but piece it together from parts like
        # domain, path, and file.
        my $html_file = "$self->{baseName}{$language}.html";
        $self->{htmlFile}{$language} = $html_file;
        $self->{href}{$language} = 'comics/' . $html_file;
        $self->{url}{$language} = "https://$domain/$self->{href}{$language}";
    }

    $self->_adjust_checks($self->{meta_data}->{$Comic::Settings::CHECKS});

    return;
}


sub _parse_xml {
    my ($xml) = @ARG;
    my $parser = XML::LibXML->new();
    $parser->set_option(huge => 1);
    return $parser->load_xml(string => $xml);
}


sub _unhtml {
    # Inkscape is XML, so it uses &lt;, &gt;, &amp;, and &quot; in it's meta
    # data. This is convenient for the HTML export, but not for adding meta
    # data to the .png file.
    my ($text) = @ARG;
    return decode_entities($text);
}


=head2 _adjust_checks

Adjusts the checks on a per-comic basis. Each comic will normally use the
default checks passed in the constructor. Comics can modify these defaults
by defining a C<Checks> entry in their metadata.

That C<Checks> meta data needs to be a JSON array containing any of these
keywords as objects (case-sensitive):

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
        my $args = ${$checks}{$name} || [];
        push @{$self->{checks}}, Comic::Modules::load_module($name, $args);
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
    if ($self->not_published_on_the_web($language)) {
        $outdir = 'generated/backlog/';
    }
    else {
        $outdir = 'generated/web/' . lc($language) . q{/};
    }
    return make_dir($outdir);
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
and C<FIX!!!> to look for.

Finally L<Comic::Check::Frames> uses named parameters in an object. The
names need to match what the module expects or they may be silently ignored.

    {
        "Check" => {
            "Comic/Check/Transcript.pm" => {},
            "Comic/Check/Actors" => [],
            "Comic::Check::DontPublish" => [ "DONT_PUBLISH", "FIX!!!" ],
            "Comic::Check::Weekday.pm" => [ 5 ],
            "Comic::Check::Frames" => {
                "FRAME_ROW_HEIGHT" => 1.25,
            },
        },
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

    foreach my $check (@{$self->{checks}}) {
        $check->check($self);
    }

    my $warnings_count = scalar @{$self->{warnings}};
    if ($warnings_count > 0) {
        my $problems = 'problem';
        $problems .= 's' if ($warnings_count > 1);

        my $msg = "$warnings_count $problems in $self->{srcFile}";
        if ($self->not_yet_published()) {
            # PerlCritic wants me to check that I/O to the console worked.
            ## no critic(InputOutput::RequireCheckedSyscalls)
            print "$msg\n";
            ## use critic
        }
        else {
            croak($msg);
        }
    }
    return;
}


=head2 get_transcript

Gets this Comic's transcript. The transcript is ordered text from this
Comic's transcript and real text layers, ordered from top left to bottom
right by frames. Usually it consists of speaker indicators and actual speech
texts, plus maybe some background texts.

Parameters:

=over 4

=item * B<language> for which language to get the transcript.

=back

=cut

sub get_transcript {
    my ($self, $language) = @ARG;

    if (!defined($self->{transcript}{$language})) {
        @{$self->{transcript}{$language}} = _append_speech_to_speaker($self->texts_in_language($language));
    }
    return @{$self->{transcript}{$language}};
}


=head2 up_to_date

Checks whether the given target file is up to date from the given source
file's point of view. A target file is up to date if both source and target
files exist and the target has a last modification time later than the
source file.

This allows simple file modification based check to skip potentially
expensive tasks when nothing has changed and hence the output will be the
same.

Parameters:

=over 4

=item * B<$source> source file, usually a Comic's C<.svg> file.

=item * B<$target> target file, usually something derived / created from the
    source file.

=back

=cut

sub up_to_date {
    my ($source, $target) = @ARG;

    # Cannot cache more, in particular cannot cache the transcript or frame
    # positions. This is because output generators need to be able to work
    # with the svg, e.g., Comic::Out::Copyright modifies it, and it does not
    # have a direct output file, so there is no easy up-to-date check.

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


=head2 all_frames_sorted

Returns all frames in this Comic, sorted from top left to bottom right.
Only considers objects in the C<Rahmen> layer.

=cut

sub all_frames_sorted {
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


=head2 get_all_layers

Gets all SVG layers defined in this Comic.

=cut

sub get_all_layers {
    my ($self) = @ARG;

    return $self->{xpath}->findnodes(_all_layers_xpath());
}


=head2 has_layer

Checks whether this Comic has all the Inkscape layer(s) by the given name(s).

Parameters:

=over 4

=item * B<@layer> For which layer(s) to look.

=back

=cut

sub has_layer {
    my ($self, @layers) = @ARG;

    foreach my $layer (@layers) {
        if (!$self->{xpath}->findnodes(_all_layers_xpath($layer))) {
            return 0;
        }
    }
    return 1;
}


sub _all_layers_xpath {
    # Builds an XPath expression to find all Inkscape layers (i.e., below
    # the svg element) with the given name(s) or all layers if no name is
    # given.
    my (@labels) = @ARG;

    my $xpath = "/$DEFAULT_NAMESPACE:svg//$DEFAULT_NAMESPACE:g[\@inkscape:groupmode='layer'";
    my $had_labels = 0;
    foreach my $l (@labels) {
        if ($had_labels == 0) {
            $xpath .= ' and (';
        }
        else {
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
    File::Path::make_path($dir);
    return $dir;
}


sub _normalized_title {
    my ($self, $language) = @ARG;

    my $title = $self->{meta_data}->{title}->{$language};
    $title =~ s/[&<>*?]//g;
    $title =~ s/\s{2}/ /g;
    $title =~ s/\s/-/g;
    $title =~ s/[^\w\d_-]//gi;
    return lc $title;
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

    return 1 if (($self->{meta_data}->{published}->{where} || '') ne 'web');

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
    # Devel::Coverage doesn't see that $UNPUBLISHED is always defined.
    # uncoverable branch false
    my $published = $self->{meta_data}->{published}->{when} || $UNPUBLISHED;
    return ($published cmp $till->ymd) > 0;
}


=head2 is_published_today

Checks if this Comic is published today.

=cut

sub is_published_today {
    my ($self) = @ARG;

    my $today = _now();
    $today->set_time_zone(_get_tz());
    my $published = $self->{meta_data}->{published}->{when} || $UNPUBLISHED;
    return ($published cmp $today->ymd) == 0;
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


=head2 not_published_on_the_web

Returns whether this Comic is not (yet) published on the web.

=cut

sub not_published_on_the_web {
    my ($self, $language) = @ARG;
    return !$self->_is_for($language) || $self->not_yet_published();
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
        foreach my $lcode (Locales->new()->get_language_codes()) {
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

Gets the normalized texts for the given language. Texts are order by frames
from left to right.

Normalized means line breaks are removed and multiple consecutive spaces are
reduced to one.

Parameters:

=over 4

=item * B<$language> Language name.

=back

=cut

sub texts_in_language {
    my ($self, $language) = @ARG;

    my $ignore_prefix = $self->{settings}->{LayerNames}->{NoTranscriptPrefix};

    # Collect needed layers in a hash, so that duplicted layer names are queried only once.
    # The code that collects the nodes from layers will pick up all duplicates, but it should
    # just run once per name. (Inkscape doesn't care about duplicated layer names.)
    my %needed_layers;
    foreach my $layer ($self->{xpath}->findnodes(_all_layers_xpath())) {
        my $name = $layer->getAttribute('inkscape:label');

        # Ignore layers without a name (no idea what they are for, probably drawing, and we'd
        # get an undefined warning from Perl), any layers which don't end in the language we
        # need, and any layers that start with the no-transcript prefix.
        next unless ($name);
        next unless ($name =~ m{$language$}x);
        next if ($ignore_prefix && $name =~ m{^$ignore_prefix}x);
        $needed_layers{$name}++;
    }

    my @found = $self->_text_nodes_in_layers(keys %needed_layers);
    my @texts;
    foreach my $node (sort { $self->_text_pos_sort($a, $b) } @found) {
        push @texts, _text_content($node);
    }

    return @texts;
}


=head2 texts_in_layer

Gets the normalized texts in the given layers, ordered by frames and then
from left to right.

Normalized means line breaks are removed and multiple consecutive spaces are
reduced to one.

If a text is in a layer within another layer, it is only reported for that
inner layer, not for its parent layer(s).

Parameters:

=over 4

=item * B<layer> Inkscape layer name(s) from which to collect texts.

=back

=cut

sub texts_in_layer {
    my ($self, @layers) = @ARG;

    my @nodes = $self->_text_nodes_in_layers(@layers);
    my @texts;
    foreach my $node (sort { $self->_text_pos_sort($a, $b) } @nodes) {
        push @texts, _text_content($node);
    }

    return @texts;
}


sub _text_nodes_in_layers {
    my ($self, @needed_layers) = @ARG;

    my @found;
    foreach my $layer (@needed_layers) {
        my $text_nodes = _all_layers_xpath($layer) . "//$DEFAULT_NAMESPACE:text";
        my @nodes = $self->{xpath}->findnodes($text_nodes);
        TEXT_NODE: foreach my $node (@nodes) {
            my $parent = $node->parentNode;
            # This loop should never hit the root element anyway. If there are texts outside of
            # layers, the xpath would not match them. Still, this loop condition looks better
            # to me than an infinite loop.
            while ($parent->localname ne 'svg') {
                my $group_is_layer = ($parent->getAttribute('inkscape:groupmode') || '') eq 'layer';
                if ($parent->localname eq 'g' && $group_is_layer) {
                    # Skip if this is inside another layer than we're looking for.
                    next TEXT_NODE if ($parent->getAttribute('inkscape:label') ne $layer);
                    last;
                }
                $parent = $parent->parentNode;
            }
            push @found, $node;
        }
    }
    return @found;
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
    foreach my $f ($self->all_frames_sorted()) {
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
    my ($self, $node) = @ARG;

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

    $self->_find_frames();
    for my $i (0..@{$self->{frame_tops}} - 1) {
        return $i if ($y < @{$self->{frame_tops}}[$i]);
    }
    return scalar @{$self->{frame_tops}};
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
    # uncoverable subroutine
    my ($file_name, $contents) = @ARG; # uncoverable statement

    open my $F, '>', $file_name; # uncoverable statement
    # uncoverable statement
    # uncoverable branch false
    print {$F} $contents or croak("Cannot write to $file_name: $OS_ERROR");
    close $F; # uncoverable statement
    return; # uncoverable statement
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


=head2 keel_over

Croak with current comic source file name and given error message.

Parameters:

=over 4

=item * B<$message> error message.

=back

=cut

sub keel_over {
    my ($self, $message) = @ARG;
    croak "$self->{srcFile} : $message";
}


=head2 warning

Add a warning to the current comic. Other code (or templates) can access
warnings in the C<@warnings}> member variable. This is the reason to not use
Perl's built in C<warn>: capture warnings per comic to show in a backlog or
summary.

If this Comic is already published, a warning is treated as error, and the
Comic keels over. The intention is that most warnings should be addressed
(or the Check that causes them should be disabled), and it's ok only for
comics in progress to have pending warnings.

Parameters:

=over 4

=item * B<$message> warning / error message.

=back

=cut

sub warning {
    my ($self, $msg) = @ARG;

    # Warnings can be duplicated if language-independent code is called in a
    # per-language loop for simplicity. Ignore those.
    ## no critic(ValuesAndExpressions::ProhibitMagicNumbers)
    return if (@{$self->{warnings}} > 0 && ${$self->{warnings}}[-1] eq $msg);
    ## use critic

    push @{$self->{warnings}}, $msg;

    # PerlCritic wants me to check that I/O to the console worked.
    ## no critic(InputOutput::RequireCheckedSyscalls)
    print {*STDOUT} "$self->{srcFile} : $msg\n";
    ## use critic

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

Copyright (c) 2015 - 2022, Robert Wenner C<< <rwenner@cpan.org> >>.
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
