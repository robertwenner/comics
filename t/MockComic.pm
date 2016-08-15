package MockComic;

use strict;
use warnings;
no warnings qw/redefine/;
use Readonly;
use Test::More;
use Comic;


our Readonly $ENGLISH = 'English';
our Readonly $META_ENGLISH = 'MetaEnglish';
our Readonly $DEUTSCH = 'Deutsch';
our Readonly $META_DEUTSCH = 'MetaDeutsch';
our Readonly $FRAMEWIDTH = 'framewidth';
our Readonly $FIGUREN = 'Figuren';
our Readonly $HINTERGRUND = 'Hintergrund';
our Readonly $TITLE = 'title';
our Readonly $TAGS = 'tags';
our Readonly $WHO = 'who';
our Readonly $IN_FILE = 'in_file';
our Readonly $MTIME = 'mtime';
our Readonly $PUBLISHED = 'published';
our Readonly $TEXTS = 'texts';
our Readonly $JSON = 'json';
our Readonly $TEXT_ID = 'theText';
our Readonly $FRAMES = 'frames';
our Readonly $CONTRIBUTORS = 'contrib';
our Readonly $XML = 'xml';


our @exported;  # hide behind assert_... sub
my %files_read;
my %file_written;
my $now;


my %defaultArgs = (
    $TITLE => {
        $ENGLISH => 'Drinking beer',
        $DEUTSCH => 'Bier trinken',
    },
    $IN_FILE => 'some_comic.svg',
    $MTIME => 0,
);


sub set_up {
    @exported = ();
    %file_written = ();
    Comic::reset_statics();
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
    my $xml = <<"HEADER";
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
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

    fake_file($args{$IN_FILE}, fake_comic(%args));

    *Comic::_slurp = sub {
        my ($name) = @_;
        die "Tried to read unmocked file '$name'" unless (defined($files_read{$name}));
        return $files_read{$name};
    };

    *Comic::_mtime = sub {
        return $args{$MTIME};
    };

    *File::Path::make_path = sub {
        return 1;
    };

    *Comic::_write_file = sub {
        my ($name, $contents) = @_;
        $file_written{$name} = $contents;
    };

    *Comic::_export_language_html = sub {
        my ($self, $language) = @_;
        push @exported, ($self->{meta_data}->{title}->{$language} || '');
        return;
    };

    *Comic::_now = sub {
        return $now || DateTime->now;
    };

    *Comic::_up_to_date = sub {
        return 1;
    };

    *Comic::_get_tz = sub {
        return '-0500';
    };

    my $comic = new Comic($args{$IN_FILE});
    $comic->export_png();
    return $comic;
}


sub _build_json {
    my %args = @_;

    my $json = '';

    $json .= _single_per_language_json($json, \%args, $TITLE); # comments series
    # Could check whether a scalar or array was passed and then generate
    # the JSON as needed, but this way it's easier to fail fast if a test
    # tries to build a JSON structure that would not exist in real life.
    $json = _array_per_language_json($json, \%args, $TAGS, $WHO); # keywords

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
    if (defined($args{$PUBLISHED})) {
        $json .= ",\n";
        $json .= <<JSON;
&quot;published&quot;: {
    &quot;when&quot;: &quot;$args{$PUBLISHED}&quot;
}
JSON
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
        foreach my $lang (keys $a{$what}) {
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
        foreach my $lang (keys $a{$what}) {
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
    foreach my $layerName (keys $args{$TEXTS}) {
        $xml .= <<"LAYER";
  <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="$layerName"
     style="display:inline">
LAYER
        foreach my $t (@{$args{$TEXTS}{$layerName}}) {
            $xml .= <<TEXT;
    <text
       xml:space="preserve"
       x="100"
       y="100"
       style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:125%;font-family:RW5;-inkscape-font-specification:'RW Medium';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       id="$TEXT_ID"
       sodipodi:linespacing="125%"><tspan
         sodipodi:role="line"
         id="tspan16222">$t</tspan>
     </text>
TEXT
        }
        $xml .= "</g>\n";
    }
    return $xml;
}


sub assert_wrote_file {
    my ($name, $contents) = @_;

    if (!defined($contents)) {
        ok(!defined($file_written{$name}), "Should not haven written $name");
    }
    elsif (ref($contents) eq '') {
        is($file_written{$name}, $contents, "Wrong content");
    }
    elsif (ref($contents) eq ref(qr{})) {
        like($file_written{$name}, $contents, "Wrong content regex");
    }
}


1;
