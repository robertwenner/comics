use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub before : Test(setup) {
    %Comic::sitemapXml = ();
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
    &quot;English&quot;: &quot;Drinking beer&quot;,
    &quot;Deutsch&quot;: &quot;Bier trinken&quot;
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    my ($comic) =  Comic->new('whatever');
    $comic->{modified} = "today";
    $comic->_addToSitemapXml();
}


sub assertWrote {
    my ($language, $xml) = @_;

    my $wrote = "";
    open(my $F, '>', \$wrote) or die "Cannot open memory handle: $!";
    Comic::_writeSitemapXml($F, $language);
    like($wrote, qr{$xml}m);
}


sub unknownLanguage : Test {
    assertWrote("Pimperanto", "");
}


sub page : Test {
    assertWrote("English", <<XML);
<loc>https://beercomics.com/drinking-beer.html</loc>
XML
}


sub lastModified : Test {
    assertWrote("English", <<XML);
<lastmod>today</lastmod>
XML
}


sub image : Test {
    assertWrote("English", <<XML);
<image:loc>https://beercomics.com/drinking-beer.png</image:loc>
XML
}


sub imageTitle : Test {
    assertWrote("English", <<XML);
<image:title>Drinking beer</image:title>
XML
}


sub imageLicense : Test {
    assertWrote("English", <<XML);
<image:license>https://beercomics.com/license.html</image:license>
XML
}
