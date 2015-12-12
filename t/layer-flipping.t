use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub setUp : Test(setup) {
    *Comic::_slurp = sub {
        return <<XML;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:format>image/svg+xml</dc:format>
        <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage" />
        <dc:title />
        <dc:creator>
          <cc:Agent>
            <dc:title>Robert Wenner</dc:title>
          </cc:Agent>
        </dc:creator>
        <dc:description>{}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:groupmode="layer"
     id="layer7"
     inkscape:label="Hintergrund"
     style="display:inline;opacity:0.35"/>
  <g
     inkscape:groupmode="layer"
     id="layer8"
     inkscape:label="Figuren"
     style="display:inline"/>
  <g
     inkscape:groupmode="layer"
     id="layer2"
     inkscape:label="Deutsch"
     style="display:inline"/>
  <g
     inkscape:groupmode="layer"
     id="layer3"
     inkscape:label="MetaDeutsch"
     style="display:inline"/>
  <g
     inkscape:groupmode="layer"
     id="layer4"
     inkscape:label="English"
     style="display:none"/>
  <g
     inkscape:groupmode="layer"
     id="layer5"
     inkscape:label="MetaEnglish"
     style="display:none"/>
  <g
     inkscape:groupmode="layer"
     id="layer6"
     inkscape:label="Rahmen"
     style="display:inline"/>
</svg>
XML
    };
    $comic = Comic->new('whatever');
}


sub assertVisible {
    my %expected = map {$_ => 1} @_;
    my $xpath = XML::LibXML::XPathContext->new($comic->{dom});
    $xpath->registerNs(Comic::DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $allLayers = Comic::_buildXpath('g[@inkscape:groupmode="layer"]');
    foreach my $layer ($comic->{xpath}->findnodes($allLayers)) {
        my $label = $layer->{"inkscape:label"};
        my $style = $layer->{"style"};
        if (exists($expected{$label})) {
            ok($style =~ m/inline/, "$label should be visible");
        }
        else {
            ok($style !~ m/inline/, "$label should not be visible");
        }
    }
}


sub germanOnly : Tests {
    $comic->_flipLanguageLayers("Deutsch", ("Deutsch" => "de", "English" =>"en"));
    assertVisible(qw(Deutsch Rahmen Figuren Hintergrund));
}


sub englishOnly : Tests {
    $comic->_flipLanguageLayers("English", ("Deutsch" => "de", "English" =>"en"));
    assertVisible(qw(English Rahmen Figuren Hintergrund));
}


sub failsOnUnknownLanguage : Test {
    eval {
        $comic->_flipLanguageLayers("Pimperanto", ("Deutsch" => "de", "English" =>"en"));
    };
    like($@, qr/no Pimperanto layer/i);
}
