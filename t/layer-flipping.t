use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub setup {
    my ($xml) = shift || "";
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
  $xml
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    $comic = Comic->new('whatever');
}


sub assert_visible {
    my %expected = map {$_ => 1} @_;
    my $xpath = XML::LibXML::XPathContext->new($comic->{dom});
    $xpath->registerNs($Comic::DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $allLayers = Comic::_build_xpath('g[@inkscape:groupmode="layer"]');
    foreach my $layer ($comic->{xpath}->findnodes($allLayers)) {
        my $label = $layer->{"inkscape:label"};
        my $style = $layer->{"style"};
        if (exists($expected{$label})) {
            ok($style =~ m/inline/, "$label should be visible");
        }
        else {
            ok($style =~ m/none/, "$label should not be visible");
        }
        $expected{$label} = 0;
    }
    foreach my $notseen (keys %expected) {
        ok($expected{$notseen} == 0, "Layer $notseen not in DOM");
    }
}


sub germanOnly : Tests {
    setup();
    $comic->_flip_language_layers("Deutsch", ("Deutsch", "English"));
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund));
}


sub englishOnly : Tests {
    setup();
    $comic->_flip_language_layers("English", ("Deutsch", "English"));
    assert_visible(qw(English Rahmen Figuren Hintergrund));
}


sub failsOnUnknownLanguage : Test {
    setup();
    eval {
        $comic->_flip_language_layers("Pimperanto", ("Deutsch", "English"));
    };
    like($@, qr/no Pimperanto layer/i);
}


sub flipsUnknownLayerWithTrailingLanguageName : Tests {
    setup('<g inkscape:groupmode="layer" id="layer18" inkscape:label="HintergrundDeutsch" style="display:none"/>');
    $comic->_flip_language_layers("Deutsch", ("Deutsch", "English"));
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund HintergrundDeutsch));
}


sub ignoresUnknownLayerWithEmbeddedLanguageName : Tests {
    setup('<g inkscape:groupmode="layer" id="layer18" inkscape:label="HintergrundDeutschUndSo" style="display:none"/>');
    $comic->_flip_language_layers("Deutsch", ("Deutsch", "English"));
    assert_visible(qw(Deutsch Rahmen Figuren Hintergrund));
}


sub keeps_background_opacity : Tests {
    setup('<g inkscape:groupmode="layer" id="layer18" inkscape:label="HintergrundDeutsch" style="display:inline;opacity:0.35"/>');
    $comic->_flip_language_layers("English", ("Deutsch", "English"));
    assert_visible(qw(English Rahmen Figuren Hintergrund));

    my $xpath = XML::LibXML::XPathContext->new($comic->{dom});
    $xpath->registerNs($Comic::DEFAULT_NAMESPACE, 'http://www.w3.org/2000/svg');
    my $theLayer = Comic::_build_xpath('g[@inkscape:label="HintergrundDeutsch"]');
    my $style = ($comic->{xpath}->findnodes($theLayer))[0]->{style};
    is($style, 'display:none;opacity:0.35');
}
