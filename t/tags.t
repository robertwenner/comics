use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


sub makeComic {
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
    &quot;English&quot;: &quot;title&quot;,
    &quot;Deutsch&quot;: &quot;Titel&quot;
},
&quot;tags&quot;: {
    &quot;English&quot;: [&quot;en1&quot;, &quot;en2&quot;],
    &quot;Deutsch&quot;: [&quot;de1&quot;]
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    local *Comic::_mtime = sub {
        return 0;
    };
    return new Comic('whatever');
}


sub before : Test(setup) {
    Comic::reset_statics();
}


sub tagsUnknownLanguage : Test {
    makeComic()->_count_tags();
    is(Comic::counts_of_in("tags", "Pimperanto"), undef);
}


sub tagsPerLanguage : Tests {
    makeComic()->_count_tags();
    is_deeply(Comic::counts_of_in("tags", "English"), { "en1" => 1, "en2", => 1 });
    is_deeply(Comic::counts_of_in("tags", "Deutsch"), { "de1" => 1 });
}


sub tagsMultipleTimes : Test {
    makeComic()->_count_tags();
    makeComic()->_count_tags();
    makeComic()->_count_tags();
    is_deeply(Comic::counts_of_in("tags", "English"), { "en1" => 3, "en2", => 3 });
}
