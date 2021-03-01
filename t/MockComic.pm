package MockComic;

use strict;
use warnings;
no warnings qw/redefine/;
use utf8;
use Readonly;
use Test::More;
use Test::Deep;
use Comic;
use Comic::Settings;
use Carp;
use JSON;

# Constants to catch typos when defining meta data.
our Readonly $ENGLISH = 'English';
our Readonly $META_ENGLISH = 'MetaEnglish';
our Readonly $DEUTSCH = 'Deutsch';
our Readonly $META_DEUTSCH = 'MetaDeutsch';
our Readonly $ESPAÑOL = 'Español';
our Readonly $META_ESPAÑOL = 'MetaEspañol';
our Readonly $FRAMEWIDTH = 'framewidth';
our Readonly $FIGUREN = 'Figuren';
our Readonly $HINTERGRUND = 'Hintergrund';
our Readonly $TITLE = 'title';
our Readonly $TAGS = 'tags';
our Readonly $WHO = 'who';
our Readonly $IN_FILE = 'in_file';
our Readonly $MTIME = 'mtime';
our Readonly $PUBLISHED_WHEN = 'published_when';
our Readonly $PUBLISHED_WHERE = 'published_where';
our Readonly $TEXTS = 'texts';
our Readonly $JSON = 'json';
our Readonly $FRAMES = 'frames';
our Readonly $CONTRIBUTORS = 'contrib';
our Readonly $TRANSLATOR = 'translator';
our Readonly $XML = 'xml';
our Readonly $DESCRIPTION = 'description';
our Readonly $COMMENTS = 'comments';
our Readonly $SERIES = 'series';
our Readonly $HEIGHT = 'height';
our Readonly $WIDTH = 'width';
our Readonly $DOMAINS = 'Domains';
our Readonly $SEE = 'see';
our Readonly $NAMESPACE_DECLARATION = 'namespace_declaration';
our Readonly $TWITTER = 'twitter';
our Readonly $SETTINGS = "settings";


my %files_read;
my @made_dirs;
my %file_written;
my $now;
my $mtime;


my %defaultArgs = (
    $TITLE => {
        $ENGLISH => 'Drinking beer',
        $DEUTSCH => 'Bier trinken',
    },
    $TAGS => {
        $ENGLISH => ['beer', 'craft'],
        $DEUTSCH => ['Bier', 'Craft'],
    },
    $SETTINGS => {
        $DOMAINS => {
            $ENGLISH => 'beercomics.com',
            $DEUTSCH => 'biercomics.de',
            $ESPAÑOL => 'cervezacomics.es',
        },
        $Comic::Settings::CHECKS => [],
    },
    $IN_FILE => 'some_comic.svg',
    $MTIME => 0,
    $HEIGHT => 200,
    $WIDTH => 600,
    $PUBLISHED_WHEN => '2016-08-01',
    $PUBLISHED_WHERE => 'web',
    $NAMESPACE_DECLARATION => '',
);


sub set_up {
    %file_written = ();
    @made_dirs = ();
    Comic::reset_statics();
    mock_methods();
}


sub mock_methods {
    *Comic::_exists = sub {
        my ($name) = @_;
        return exists $files_read{$name} && defined($files_read{$name});;
    };

    *File::Slurper::read_text = sub {
        my ($name) = @_;
        confess("Tried to read unmocked file '$name'") unless (defined($files_read{$name}));
        return $files_read{$name};
    };

    *Comic::_mtime = sub {
        return $mtime;
    };

    *File::Path::make_path = sub {
        push @made_dirs, @_;
        return 1;
    };

    *Comic::write_file = sub {
        my ($name, $contents) = @_;
        $file_written{$name} = $contents;
    };

    *Comic::_now = sub {
        return $now ? $now->clone() : DateTime->now;
    };

    *Comic::_up_to_date = sub {
        my ($source, $target) = @_;
        # Most tests use XML, so tell them to not use the cache.
        return 0;
    };

    *Comic::_get_tz = sub {
        return '-0500';
    };

    *Comic::_file_size = sub {
        return 1024;
    };

    *Imager::QRCode::plot_qrcode = sub {
        return Imager->new;
    };

    *Imager::write = sub {
        return 1;
    }
}


sub fake_now {
    $now = shift;   # should this be a NOW => ... param to make_comic?
}


sub fake_file {
    my ($name, $contents) = @_;
    $files_read{$name} = $contents;
}


sub fake_comic {
    my %args = @_;

    my $json = _build_json(%args);
    my $namespace = ${args}{$NAMESPACE_DECLARATION};
    my $xml = <<"HEADER";
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   $namespace
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{$json}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
HEADER

    $xml .= _add_frame_border(${args}{$FRAMEWIDTH});
    $xml .= _add_frames(%args);
    $xml .= _add_text_layers(%args);

    $xml .= $args{$XML} || '';
    $xml .= '</svg>';
    return $xml;
}


sub make_comic {
    my %args = (%defaultArgs, @_);

    $mtime = $args{$MTIME};
    fake_file($args{$IN_FILE}, fake_comic(%args));

    my $comic = new Comic($args{$IN_FILE}, $args{$SETTINGS});
    $comic->{height} = $args{$HEIGHT};
    $comic->{width} = $args{$WIDTH};
    return $comic;
}


sub _build_json {
    my %args = @_;

    my $json = '';

    $json .= _single_per_language_json($json, \%args, $TITLE, $DESCRIPTION,
        $COMMENTS, $SERIES, $TRANSLATOR);
    # Could check whether a scalar or array was passed and then generate
    # the JSON as needed, but this way it's easier to fail fast if a test
    # tries to build a JSON structure that would not exist in real life.
    $json = _array_per_language_json($json, \%args, $TAGS, $WHO, $TWITTER);
    $json = _hash_per_language_json($json, \%args, $SEE);

    # Meta info: value, language independent
    my $wrote = 0;
    foreach my $what ($CONTRIBUTORS) {
        if (defined($args{$what})) {
            $json .= ",\n" if ($json ne '');
            if (ref $args{$what} eq ref[]) {
                my $arr = '';
                foreach my $v (@{$args{$what}}) {
                    $arr .= ', ' if ($arr ne '');
                    $arr .= "&quot;$v&quot;" if (defined($v)); # empty array check
                }
                $json .= "    &quot;$what&quot;: [$arr]";
            }
            else {
                $json .= "    &quot;$what&quot;: &quot;$args{$what}&quot;";
            }
            $wrote = 1;
        }
    }
    $json .= "\n" if ($wrote);

    # Special: published takes when and where
    if (defined($args{$PUBLISHED_WHEN}) || defined($args{$PUBLISHED_WHERE})) {
        $json .= ",\n&quot;published&quot;: {\n";
        if (defined($args{$PUBLISHED_WHEN})) {
            $json .= "    &quot;when&quot;: &quot;$args{$PUBLISHED_WHEN}&quot;";
            $json .= ",\n" if (defined($args{$PUBLISHED_WHERE}));
        }
        if (defined($args{$PUBLISHED_WHERE})) {
            $json .= "    &quot;where&quot;: &quot;$args{$PUBLISHED_WHERE}&quot;";
        }
        $json .= "}\n";
    }

    # Manually defined JSON
    if (defined($args{$JSON})) {
        $json .= ",\n" if ($json ne '');
        $json .= $args{$JSON};
    }

    return $json;
}


sub _single_per_language_json {
    my ($json, $args, @names) = @_;

    my %a = %{$args};
    foreach my $what (@names) {
        next unless(defined($a{$what})); # Tests may not define all possible properties

        my $hadOne = 0;
        foreach my $lang (keys %{$a{$what}}) {
            if ($hadOne) {
                $json .= ",\n";
            }
            else {
                $json .= ",\n" if ($json ne '');
                $json .= "    &quot;$what&quot;: {\n";
                $hadOne = 1;
            }
            $json .= "        &quot;$lang&quot;: &quot;$a{$what}{$lang}&quot;";
        }
        $json .= "\n    }" if ($hadOne);
    }
    return $json;
}


sub _array_per_language_json {
    my ($json, $args, @names) = @_;

    my %a = %{$args};
    foreach my $what (@names) {
        next unless(defined($a{$what})); # Tests may not define all properties

        my $hadOne = 0;
        foreach my $lang (keys %{$a{$what}}) {
            if ($hadOne) {
                $json .= ",\n";
            }
            else {
                $json .= ",\n" if ($json ne '');
                $json .= "    &quot;$what&quot;: {\n";
                $hadOne = 1;
            }

            $json .= "        &quot;$lang&quot;: ";
            my $elems = '';
            foreach my $v (@{$a{$what}{$lang}}) {
                $elems .= ', ' unless ($elems eq '');
                $elems .= "&quot;$v&quot;";
            }
            $json .= "[$elems]";
        }
        $json .= "\n    }" if ($hadOne);
    }
    return $json;
}


sub _hash_per_language_json {
    my ($json, $args, @names) = @_;

    my %a = %{$args};
    foreach my $what (@names) {
        next unless(defined($a{$what})); # Tests may not define all properties

        my $hadOne = 0;
        foreach my $lang (keys %{$a{$what}}) {
            if ($hadOne) {
                $json .= ",\n";
            }
            else {
                $json .= ",\n" if ($json ne '');
                $json .= "    &quot;$what&quot;: {\n";
                $hadOne = 1;
            }

            $json .= "        &quot;$lang&quot;: {\n";
            my $elems = '';
            foreach my $v (keys %{$a{$what}{$lang}}) {
                $elems .= ', ' unless ($elems eq '');
                $elems .= "            &quot;$v&quot;: &quot;${a{$what}{$lang}{$v}}&quot;\n";
            }
            $json .= "$elems        }";
        }
        $json .= "\n    }" if ($hadOne);
    }
    return $json;
}


sub _add_frame_border {
    my ($width) = @_;

    return '' unless ($width);
    return <<"FRAME";
  <g
     inkscape:groupmode="layer"
     id="layer6"
     inkscape:label="Rahmen"
     sodipodi:insensitive="true">
    <rect
       style="display:inline;fill:none;stroke:#000000;stroke-width:$width;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
       id="rect6486"
       width="234.86922"
       height="178.6805"
       x="0.65975022"
       y="873.02191" />
  </g>
FRAME
}


sub _add_frames {
    my %args = @_;

    my $frames = $args{$FRAMES};
    return '' if (!defined($frames) || !@{$frames});

    my $xml = <<'XML';
  <g
     inkscape:groupmode="layer"
     id="layer6"
     inkscape:label="Rahmen"
     sodipodi:insensitive="true">
XML
    for (my $i = 0; $i < @{$frames}; $i += 4) {
        my ($width, $height, $x, $y) = @{$frames}[$i, $i + 1, $i + 2, $i + 3];
        $xml .= <<"XML";
    <rect
       style="display:inline;fill:none;stroke:#000000;stroke-width:1.08581364;stroke-linecap:butt;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
       id="rect6486"
       width="$width"
       height="$height"
       x="$x"
       y="$y"/>
XML
    }
    $xml .= "</g>\n";
    return $xml;
}


sub _add_text_layers {
    my %args = @_;

    return '' unless(defined $args{$TEXTS});

    my $xml = '';
    foreach my $layerName (keys %{$args{$TEXTS}}) {
        $xml .= <<"LAYER";
  <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="$layerName"
     style="display:inline">
LAYER
        foreach my $t (@{$args{$TEXTS}{$layerName}}) {
            my $x = 100;
            my $y = 100;
            my $text = $t;
            if (ref($t) eq ref {}) {
                $x = $t->{x};
                $y = $t->{y};
                $text = $t->{t};
            }
            $xml .= <<TEXT;
    <text
       xml:space="preserve"
       x="$x"
       y="$y"
       style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:125%;font-family:RW5;-inkscape-font-specification:'RW Medium';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       sodipodi:linespacing="125%"><tspan
         sodipodi:role="line"
         id="tspan16222">$text</tspan>
     </text>
TEXT
        }
        $xml .= "</g>\n";
    }
    return $xml;
}


sub assert_made_dirs {
    is_deeply([@made_dirs], [@_], 'Created wrong dirs');
}


sub assert_wrote_file {
    my ($name, $contents) = @_;

    if (!defined($contents)) {
        ok(!defined($file_written{$name}), "Should not haven written to $name");
    }
    elsif (ref($contents) eq '') {
        is($file_written{$name}, $contents, "Wrong content in $name");
    }
    elsif (ref($contents) eq ref(qr{})) {
        like($file_written{$name}, $contents, "Content in $name should match regex");
    }
    else {
        confess("Cannot match on $contents");
    }
}


sub assert_didnt_write_in_file {
    my ($name, $contents) = @_;

    if (!$contents) {
        ok(!defined $file_written{$name}, "Shouldn't have written to $name at all");
    }
    elsif (ref($contents) eq ref(qr{})) {
        unlike($file_written{$name}, $contents, "Shouldn't have written that to $name");
    }
    else {
        confess("Cannot match on $contents");
    }
}


sub assert_wrote_file_json {
    my ($name, $contents) = @_;

    cmp_deeply(from_json($file_written{$name}), $contents, "Content in $name should be same JSON");
}


1;
