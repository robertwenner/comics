use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use Comic;

__PACKAGE__->runtests() unless caller;

my $titleDe;
my $titleEn;


BEGIN {
    $titleDe = "titleDe";
    $titleEn = "titleEn";
}


sub before : Test(setup) {
    *Comic::_slurp = sub {
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
    &quot;en&quot;: &quot;$titleEn&quot;,
    &quot;de&quot;: &quot;$titleDe&quot;
}
}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
}


sub duplicatedTitle : Test {
    $titleEn = "duplicated title";
    my $c1 = Comic->new("one file");
    $c1->_sanityChecks("en");
    my $c2 = Comic->new("other file");
    eval {
        $c2->_sanityChecks("en");
    };
    like($@, qr/Duplicated en title/i);
}


sub duplicatedTitleCaseInsensitive : Test {
    $titleEn = "clever title";
    my $c1 = Comic->new("one file");
    $c1->_sanityChecks("en");
    $titleEn = "Clever Title";
    my $c2 = Comic->new("other file");
    eval {
        $c2->_sanityChecks("en");
    };
    like($@, qr/Duplicated en title/i);
}


sub duplicatedTitleWhitespace : Test {
    $titleEn = " white spaced";
    my $c1 = Comic->new("one file");
    $c1->_sanityChecks("en");
    $titleEn = "white   spaced ";
    my $c2 = Comic->new("other file");
    eval {
        $c2->_sanityChecks("en");
    };
    like($@, qr/Duplicated en title/i);
}


sub duplicateTitleAllowedInDifferentLanguages : Test {
    $titleEn = "language title";
    $titleDe = "language title";
    my $c1 = Comic->new("one file");
    $c1->_sanityChecks("en");
    my $c2 = Comic->new("other file");
    # This would throw if it failed
    $c2->_sanityChecks("de");
    ok(1);
}


sub idempotent : Test {
    $titleEn = "idempotent";
    my $c = Comic->new("idempotent");
    $c->_sanityChecks("en");
    # This would throw if it failed
    $c->_sanityChecks("en");
    ok(1);
}
