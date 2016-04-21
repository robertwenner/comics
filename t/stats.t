use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;

sub makeComic {
    my ($pubDate) = @_;

    local *Comic::_slurp = sub {
        return <<XML;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{
&quot;title&quot;: {
    &quot;Deutsch&quot;: &quot;Bier trinken&quot;
},
&quot;tags&quot;: {
    &quot;Deutsch&quot;: [&quot;Bier&quot;]
},
&quot;published&quot;: {
    &quot;when&quot;: &quot;$pubDate&quot;
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="Deutsch"
     style="display:inline"/>
</svg>
XML
    };
    local *Comic::_mtime = sub {
        return 0;
    };
    return new Comic('whatever');
}


sub comic_counts_per_language : Tests {
    local *Comic::_svg_to_png = sub {
        # ignore...
    };
    foreach my $i (1..3) {
        makeComic("2016-01-$i")->export_png("English" => "en", "Deutsch" => "de");
    }
    is(Comic::counts_of_in('comics', 'Deutsch'), 3, "for Deutsch");
    is(Comic::counts_of_in('comics', 'English'), undef, "for English");
}
