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
    my ($published, $language) = @_;

    $language = $language || 'English';
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
    &quot;$language&quot;: &quot;Drinking beer&quot;
},
&quot;published&quot;: {
    &quot;when&quot;: &quot;$published&quot;
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
    my $comic = Comic->new('whatever');
    $comic->{modified} = $published;
    $comic->{pngFile}{$language} = "drinking-beer.png";
    return $comic;
}


sub assertWrote {
    my ($comic, $contentsExpected) = @_;

    my $fileNameIs;   
    my $contentsIs;

    *Comic::_write_file = sub {
        ($fileNameIs, $contentsIs) = @_;
    };
    $comic->_write_sitemap_xml_fragment("English");
    if ($contentsExpected eq '^$') {
        is($fileNameIs, undef, 'Should not have written anything');
    }
    else {
        is($fileNameIs, 'generated/english/tmp/sitemap/drinking-beer.xml', 'Wrong file name');
    }
    like($contentsIs, qr{$contentsExpected}m, 'Wrong content');
}


sub page : Tests {
    my $comic = make_comic('2016-01-01');
    assertWrote($comic, '<loc>https://beercomics.com/comics/drinking-beer.html</loc>');
}


sub last_modified : Tests {
    my $comic = make_comic('2016-01-01');
    assertWrote($comic, '<lastmod>2016-01-01</lastmod>');
}


sub image : Tests {
    my $comic = make_comic('2016-01-01');
    assertWrote($comic, '<image:loc>https://beercomics.com/comics/drinking-beer.png</image:loc>');
}


sub image_title : Tests {
    my $comic = make_comic('2016-01-01');
    assertWrote($comic, '<image:title>Drinking beer</image:title>');
}


sub image_license : Tests {
    my $comic = make_comic('2016-01-01');
    assertWrote($comic, '<image:license>https://beercomics.com/imprint.html</image:license>');
}


sub unpublished : Tests {
    my $comic = make_comic('3016-01-01', 'English');
    assertWrote($comic, '^$'); # should not write anything
}


sub wrong_language : Tests {
    my $comic = make_comic('2016-01-01', 'Deutsch');
    assertWrote($comic, '^$'); # should not write anything
}
