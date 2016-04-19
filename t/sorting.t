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
</svg>
XML
    };
    local *Comic::_mtime = sub {
        return 0;
    };
    return new Comic('whatever');
}


sub sortEquals : Test {
    my $today = makeComic("2016-04-17");
    ok(Comic::_compare($today, $today) == 0);
}


sub sortPubDate : Tests {
    my $today = makeComic("2016-04-17");
    my $yesterday = makeComic("2016-04-16");
    ok(Comic::_compare($today, $yesterday) > 0);
    ok(Comic::_compare($yesterday, $today) < 0);
}


sub sortArray : Test {
    my $jan = makeComic("2016-01-01");
    my $feb = makeComic("2016-02-01");
    my $mar = makeComic("2016-03-01");

    is_deeply(
        [sort Comic::_compare $feb, $mar, $jan],
        [$jan, $feb, $mar]);
}
