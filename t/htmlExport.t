use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub makeXml {
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
    &quot;en&quot;: &quot;$title&quot;
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

    return new Comic('whatever');
}
    

sub escapesXmlSpecialCharactersText : Test {
    my $wrote = "";
    open(my $F, '>', \$wrote) or die "Cannot open memory handle: $!";
    my $comic = makeXml("title", "bläh-bläh");
    $comic->_exportHtml($F, "en", "English");
    ok($wrote =~ m{<p>bl&auml;h-bl&auml;h</p>}m);
}


sub escapesXmlSpecialCharactersJson : Test {
    my $wrote = "";
    open(my $F, '>', \$wrote) or die "Cannot open memory handle: $!";
    my $comic = makeXml('&lt;title \&quot;quoted\&quot; &amp; umläüted&gt;', "content");
    $comic->_exportHtml($F, "en", "English");
    ok($wrote =~
        m{<h1>&lt;title &quot;quoted&quot; &amp; uml&auml;&uuml;ted&gt;</h1>}m);
}


sub noExportIfNotMetaForThatLanguage : Test {
    local *Comic::_makeComicsPath = sub { die("should not make a path"); };
    my $comic = makeXml('title', 'content');
    $comic->_exportLanguageHtml('de', 'Deutsch');
    ok(1); # Would have failed above
}
