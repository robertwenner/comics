use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;


my $comic;


sub setup : Test(setup) {
    *Comic::_slurp = sub {
        my ($fileName) = @_;
        if ($fileName eq 'comic') {
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
[% png_file %] [% height %] by [% width %]
[% transcript %]
TEMPLATE
        }
    };
    local *Comic::_mtime = sub {
        return 0;
    };
    *File::Path::make_path = sub {
        return 1;
    };
    $comic = new Comic('comic');
    $comic->{height} = 200;
    $comic->{width} = 600;
}


sub simpleExpression : Test {
    is(Comic::_templatize('[% modified %]', ("modified" => "today")), "today");
}


sub caseSensitive : Test {
    eval {
        Comic::_templatize('[% modified %]', ("MODified" => "today"));
    };
    like($@, qr/undefined variable/i);
}


sub whiteSpace : Test {
    is(Comic::_templatize("[%modified\t\t %]", ("modified" => "today")), "today");
}


sub utf8 : Test {
    is(Comic::_templatize('[%modified%]', ("modified" => "töday")), "töday");
}


sub templateSyntaxError : Test {
    eval {
        Comic::_templatize('[% modified ', ("modified" => "today"));
    };
    like($@, qr/Unresolved template marker/i);
}


sub unknownVariable : Test {
    eval {
        Comic::_templatize('[% modified %]', ("a" => "b"));
    };
    like($@, qr/undefined variable/i);
}


sub array : Test {
    is(Comic::_templatize(
        "[% FOREACH a IN array %][% a %][% END %]", ("array" => ["a", "b", "c"])),
        "abc");
}


sub hash : Test {
    is(Comic::_templatize(
        "[% hash.key %]", ("hash" => {"key" => "the key"})),
        "the key");
}


sub function : Test {
    is(Comic::_templatize(
        "[% func %]", ("func" => &{ return "works" })),
        "works");
}


sub object_member : Tests {
    is($comic->{file}, "comic");
    is(Comic::_templatize(
        "[%comic.file%]", ("comic" => $comic)),
        "comic");
    is(Comic::_templatize(
        "[%comic.meta_data.title.Deutsch%]", ("comic" => $comic)),
        "Bier trinken");
}


sub object_function_code_ref : Tests {
    is(Comic::_templatize(
        "[%notFor(comic, 'Pimperanto')%]", (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        1);
    is(Comic::_templatize(
        "[%notFor(comic, 'Deutsch')%]", (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        0);
}


sub object_function_wrapped : Tests {
    is(Comic::_templatize(
        "[%notFor(comic, 'Pimperanto')%]", (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        1);
    is(Comic::_templatize(
        "[%notFor(comic, 'Deutsch')%]", (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        0);

    is(Comic::_templatize(
        "[%notFor('Pimperanto')%]", ("notFor" => sub { return $comic->_not_for(@_);})),
        1);
    is(Comic::_templatize(
        "[%notFor('Deutsch')%]", ("notFor" => sub { return $comic->_not_for(@_);})),
        0);
}


sub fromComic : Tests {
    my $wrote = $comic->_do_export_html("Deutsch", ());
    like($wrote, qr/Bier trinken/m);
    like($wrote, qr/1970-01-01/m);
    like($wrote, qr/bier-trinken\.png/m);
    like($wrote, qr/200 by 600/m);
}
