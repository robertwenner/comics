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
    &quot;English&quot;: &quot;$titleEn&quot;,
    &quot;Deutsch&quot;: &quot;$titleDe&quot;
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
}


sub duplicated_title : Test {
    $titleEn = "duplicated title";
    my $c1 = Comic->new("one file");
    $c1->_sanity_checks("English");
    my $c2 = Comic->new("other file");
    eval {
        $c2->_sanity_checks("English");
    };
    like($@, qr/Duplicated English title/i);
}


sub duplicated_title_case_insensitive : Test {
    $titleEn = "clever title";
    my $c1 = Comic->new("one file");
    $c1->_sanity_checks("English");
    $titleEn = "Clever Title";
    my $c2 = Comic->new("other file");
    eval {
        $c2->_sanity_checks("English");
    };
    like($@, qr/Duplicated English title/i);
}


sub duplicated_title_whitespace : Test {
    $titleEn = " white spaced";
    my $c1 = Comic->new("one file");
    $c1->_sanity_checks("English");
    $titleEn = "white   spaced ";
    my $c2 = Comic->new("other file");
    eval {
        $c2->_sanity_checks("English");
    };
    like($@, qr/Duplicated English title/i);
}


sub duplicate_title_allowed_in_different_languages : Test {
    $titleEn = "language title";
    $titleDe = "language title";
    my $c1 = Comic->new("one file");
    $c1->_sanity_checks("English");
    my $c2 = Comic->new("other file");
    # This would throw if it failed
    $c2->_sanity_checks("Deutsch");
    ok(1);
}


sub idempotent : Test {
    $titleEn = "idempotent";
    my $c = Comic->new("idempotent");
    $c->_sanity_checks("English");
    # This would throw if it failed
    $c->_sanity_checks("English");
    ok(1);
}
