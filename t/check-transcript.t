use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub make_comic {
    my ($layerName, @texts) = @_;

    *Comic::_slurp = sub {
        my $xml = <<HEAD;
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   version="1.1"
   inkscape:version="0.91 r">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{
&quot;title&quot;: {
    &quot;Deutsch&quot;: &quot;Bier trinken&quot;
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
HEAD
        foreach my $t (@texts) {
            $xml .= <<TEXT;    
  <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="$layerName"
     style="display:inline">
    <text
       xml:space="preserve"
       style="font-style:normal;font-variant:normal;font-weight:500;font-stretch:normal;font-size:25px;line-height:125%;font-family:RW5;-inkscape-font-specification:'RW Medium';text-align:start;letter-spacing:0px;word-spacing:0px;writing-mode:lr-tb;text-anchor:start;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
       id="text16220"
       sodipodi:linespacing="125%"><tspan
         sodipodi:role="line"
         id="tspan16222">$t</tspan>
     </text>
  </g>
TEXT
        }
        $xml .= <<FOOT;
</svg>
FOOT
        return $xml;
    };
    *Comic::_mtime = sub {
        return 0;
    };
    return Comic->new('whatever');
}


# Should this rather check that no two meta texts come after each other?
# Except in the beginning, where the first is an intro line? 
# So it would have to have a meta first (maybe not always?), then a speaker
# and then...?
#
# intro? (speaker speech+)+
#
# What about a speech bubble, a meta tag describing a picture, and a name tag?
# Do all meta tags need to have trailing colons? Only speaker markers? What
# else would be there?

sub same_name_no_content() : Test {
    my $comic = make_comic('MetaDeutsch', 'Max:', 'Max:');
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{'Max:' after 'Max:'}i);
}


sub different_names_no_content() : Test {
    my $comic = make_comic('MetaDeutsch', 'Max:', 'Paul:');
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{'Paul:' after 'Max:'}i);
}


sub description_with_colon_speaker() : Test {
    my $comic = make_comic('MetaDeutsch', 'Es war einmal ein Bier...', 'Paul:');
    $comic->_check_transcript('Deutsch');
    ok(1);
}


sub same_name_colon_missing() : Test {
    my $comic = make_comic('MetaDeutsch', 'Paul:', 'Paul');
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{'Paul' after 'Paul:'}i);
}
