use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub before : Test(setup) {
    *Comic::_slurp = sub {
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
    &quot;English&quot;: &quot;Drinking beer&quot;
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    *File::Path::make_path = sub {
        return 1;
    };
    $comic = Comic->new('whatever');
    $comic->{modified} = "today";
    $comic->{pngFile} = "drinking-beer.png";
}


sub assertWrote {
    my ($contentsExpected) = @_;

    my $fileNameIs;   
    my $contentsIs;

    *Comic::_write_file = sub {
        ($fileNameIs, $contentsIs) = @_;
    };
    $comic->_write_sitemap_xml_fragment("English");
    is("generated/english/tmp/drinking-beer.xml", $fileNameIs);
    like($contentsIs, qr{$contentsExpected}m);
}


sub page : Tests {
    assertWrote('<loc>https://beercomics.com/comics/drinking-beer.html</loc>');
}


sub last_modified : Tests {
    assertWrote('<lastmod>today</lastmod>');
}


sub image : Tests {
    assertWrote('<image:loc>https://beercomics.com/comics/drinking-beer.png</image:loc>');
}


sub image_title : Tests {
    assertWrote('<image:title>Drinking beer</image:title>');
}


sub image_license : Tests {
    assertWrote('<image:license>https://beercomics.com/imprint.html</image:license>');
}
