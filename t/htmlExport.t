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
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    *File::Path::make_path = sub {
        return 1;
    };
    my $comic = new Comic('whatever');
    return $comic;
}


sub noExportIfNotMetaForThatLanguage : Test {
    local *Comic::_makeComicsPath = sub { die("should not make a path"); };
    my $comic = makeEnglishComic('title', 'content');
    $comic->_exportLanguageHtml('Deutsch', ("Deutsch" => "de"));
    ok(1); # Would have failed above
}

