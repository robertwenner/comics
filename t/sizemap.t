use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;
use Test::Deep;
use DateTime;
use Comic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    Comic::reset_statics();
}


sub make_comic {
    my ($width, $height) = @_;

    *Comic::_slurp = sub {
        my ($file) = @_;
        return <<XML;
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    *Comic::_mtime = sub {
        return 0;
    };
    my $comic = Comic->new('whatever');
    $comic->{height} = $height;
    $comic->{width} = $width;
    return $comic;
}


sub sorting : Tests {
    my $a = make_comic(10, 100);
    my $b = make_comic(20, 90);
    my $c = make_comic(30, 80);

    is_deeply([$c, $b, $a], [sort Comic::_by_height ($b, $a, $c)]);
    is_deeply([$a, $b, $c], [sort Comic::_by_width ($b, $a, $c)]);
}
