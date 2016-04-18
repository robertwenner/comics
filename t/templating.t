use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $wrote;
my $F;
my $comic;


sub setUp : Test(setup) {
    *Comic::_slurp = sub {
        my ($fileName) = @_;
        if ($fileName eq "first") {
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
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
        }
        else {
            return <<TEMPLATE;
Biercomics: [% title %]
last-modified: [% modified %]
description: [% description %]
[% title %]
[% pngFile %] [% height %] by [% width %]
[% transcript %]
% first %]
% prev %]
% next %]
TEMPLATE
        }
    };
    local *Comic::_mtime = sub {
        return 0;
    };
    *File::Path::make_path = sub {
        return 1;
    };
    $comic = new Comic('first');
    $comic->{height} = 200;
    $comic->{width} = 600;

    $wrote = "";
    open($F, '>', \$wrote) or die "Cannot open memory handle: $!";
} 


sub simpleExpression : Test {
    is($comic->_templatize('[% modified %]', ("modified" => "today")), "today");
}


sub caseSensitive : Test {
    eval {
        $comic->_templatize('[% modified %]', ("MODified" => "today"));
    };
    like($@, qr/undefined variable/i);
}


sub whiteSpace : Test {
    is($comic->_templatize("[%modified\t\t %]", ("modified" => "today")), "today");
}


sub utf8 : Test {
    is($comic->_templatize('[%modified%]', ("modified" => "töday")), "töday");
}


sub templateSyntaxError : Test {
    eval {
        $comic->_templatize('[% modified ', ("modified" => "today"));
    };
    like($@, qr/Unresolved template marker/i);
}


sub unknownVariable : Test {
    eval {
        $comic->_templatize('[% modified %]', ("a" => "b"));
    };
    like($@, qr/undefined variable/i);
}


sub fromComic : Tests {
    $comic->_exportHtml($F, "Deutsch", ());
    like($wrote, qr/Bier trinken/m);
    like($wrote, qr/1970-01-01/m);
    like($wrote, qr/bier-trinken\.png/m);
    like($wrote, qr/200 by 600/m);
}
