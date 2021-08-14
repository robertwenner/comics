use strict;
use warnings;
use Image::SVG::Transform;

use base 'Test::Class';
use Test::More;

__PACKAGE__->runtests() unless caller;


sub transform {
    my ($what, $x, $y) = @_;
    my $transformer = Image::SVG::Transform->new();
    $transformer->extract_transforms($what);
    return $transformer->transform([$x, $y]);
}


sub croaks_on_unknown_transform : Tests {
    eval {
        transform("whatever", 0, 0);
    };
    like($@, qr{unable to parse}i);
}


sub basic_operations : Tests {
    is_deeply([12, 34], transform("", 12, 34), "no transformation");
    is_deeply([-200, 100], transform("rotate(90)", 100, 200), "rotate");
    is_deeply([50, 20], transform("scale(0.5, 0.1)", 100, 200), "scale");
    is_deeply([150, 400], transform("matrix(1.5, 0, 0, 2, 0, 0)", 100, 200), "matrix");
    is_deeply([5, 10], transform("scale(0.5, 0.1) scale(0.1, 0.5)", 100, 200), "multiple");
}
