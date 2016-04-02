use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub makeEnglishComic {
    my ($title, $content) = @_;

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
    &quot;English&quot;: &quot;$title&quot;
},
&quot;tags&quot;: {
    &quot;English&quot;: [ &quot;JSON, tags, ähm&quot; ]
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g inkscape:groupmode="layer" inkscape:label="English">
    <text x="-138.3909" y="1118.5272">
       <tspan id="tspan4153" x="-138.3909" y="1118.5272">$content</tspan>
    </text>
  </g>
</svg>
XML
    };
    return withFakedAttributes(new Comic('whatever'));
}


sub makeEnglishGermanComic {
    my ($titleEn, $contentEn, $titleDe, $contentDe) = @_;

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
    &quot;English&quot;: &quot;$titleEn&quot;,
    &quot;Deutsch&quot;: &quot;$titleDe&quot;
},
&quot;tags&quot;: {
    &quot;English&quot;: [ &quot;tag one&quot;, &quot;tag two&quot;],
    &quot;Deutsch&quot;: [ &quot;tag de&quot; ]
},

}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g inkscape:groupmode="layer" inkscape:label="English">
    <text x="-138.3909" y="1118.5272">
       <tspan id="tspan4153" x="-138.3909" y="1118.5272">$contentEn</tspan>
    </text>
  </g>
  <g inkscape:groupmode="layer" inkscape:label="Deutsch">
    <text x="-138.3909" y="1118.5272">
       <tspan id="tspan4153" x="-138.3909" y="1118.5272">$contentDe</tspan>
    </text>
  </g>
</svg>
XML
    };
    return withFakedAttributes(new Comic('whatever'));
}


sub withFakedAttributes {
    my ($comic) = @_;    
    $comic->{modified} = "today";
    $comic->{height} = 200;
    $comic->{width} = 600;
    return $comic;
}


my $wrote;
my $F;


sub before : Test(setup) {
    $wrote = "";
    open($F, '>', \$wrote) or die "Cannot open memory handle: $!";
} 


sub escapesXmlSpecialCharactersFromText : Test {
    my $comic = makeEnglishComic("title", "bläh-bläh");
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~ m{bl&auml;h-bl&auml;h}m);
}


sub escapesXmlSpecialCharactersFromJson : Test {
    my $comic = makeEnglishComic('&lt;title \&quot;quoted\&quot; &amp; umläüted&gt;', "content");
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~
        m{<h1>Beer comic: &lt;title &quot;quoted&quot; &amp; uml&auml;&uuml;ted&gt;</h1>}m);
}


sub noExportIfNotMetaForThatLanguage : Test {
    local *Comic::_makeComicsPath = sub { die("should not make a path"); };
    my $comic = makeEnglishComic('title', 'content');
    $comic->_exportLanguageHtml('Deutsch', ("Deutsch" => "de"));
    ok(1); # Would have failed above
}


sub doctype : Test {
    my $comic = makeEnglishComic('Tötle!', "content");
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~
        m{^<!DOCTYPE html>}g);
}


sub image : Tests {
    my $comic = makeEnglishComic('Tötle!', "content");
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~
        m{<object[^>]*\bdata="https://beercomics.com/comics/ttle.png"[^>]*>}m,
        "data missing in $wrote");
    ok($wrote =~
        m{<object[^>]*\btype="image/png"[^>]*>}m,
        "type missing in $wrote");
}


sub imageDimensions : Tests {
    my $comic = makeEnglishComic("title", "content");
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~
        m{<object[^>]*\bwidth="600"[^>]*>}m,
        "width missing in $wrote");
    ok($wrote =~
        m{<object[^>]*\bheight="200"[^>]*>}m,
        "height missing in $wrote");
}


sub imageTranscript : Test {
    my $comic = makeEnglishComic("title", "content");
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~
        m{<object[^>]+>\s*<p>content</p>\s*</object>}m);
}


sub title : Tests {
    my $comic = makeEnglishComic('Drinking Beer', "content");
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~ m{<h1>Beer comic: Drinking Beer</h1>});
    ok($wrote =~ m{<title>Beer comic: Drinking Beer</title>});
}


sub metaDescription : Test {
    my $comic = makeEnglishComic('title', 'content');
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~ m{<meta name="description" content="beer, comic, JSON, tags, &auml;hm"/>}m);
}


sub metaAuthor : Test {
    my $comic = makeEnglishComic('title', 'content');
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~ m{<meta name="author" content="Robert Wenner"/>}m);
}


sub metaLastModified : Test {
    my $comic = makeEnglishComic('title', 'content');
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~ m{<meta name="last-modified" content="today"/>}m);
}


sub metaCharset : Test {
    my $comic = makeEnglishComic('title', 'content');
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~ m{<meta charset="utf-8"/>}m);
}


sub language : Test {
    my $comic = makeEnglishComic('title', 'content');
    $comic->_exportHtml($F, "English", ("English" => "en"));
    ok($wrote =~ m{<html lang="en">}m);
}


__END__
sub header : Test {
    # About / imprint / license
}


sub footer : Test {
    # About / imprint / license
}


sub prevNextLinks : Test {
}


sub seriesLink : Test {
}


sub siteMapLink : Test {
}


sub siteMapXmlLink : Test {
}


sub directImageLinkForEmbedding : Test {
}


sub imageWidthAndHeight : Test {
}


sub otherLanguagesLinks : Tests {
    my $comic = makeEnglishGermanComic('Beer', 'Beer here', 'Bier', 'Bier hier');
    $comic->_exportHtml($F, "en", "English");
    ok($wrote =~ m{<a href="https://www.biercomic.de/bier.html" alt="Deutsche Version">DE</a>});
    ok($wrote !~ m{<a href="https://www.beercomic.com/beer.html" alt="English version">EN</a>});
    ok(0, "check for nav block");
}


sub licenseText : Test {
}


sub relAuthor : Test {
}


sub relArchives : Test {
}


sub relRssFeed : Test {
}


sub relStartPrevPost : Test {
    # for series
}


sub relFavIcon : Test {
}


sub relLicense : Test {
}


sub pubDate : Test {
    # <time> element --- needed?
}

