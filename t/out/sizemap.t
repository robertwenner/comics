use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Out::Sizemap;


__PACKAGE__->runtests() unless caller;


my $sizemap;


sub set_up : Test(setup) {
    MockComic::set_up();
    $sizemap = Comic::Out::Sizemap->new(
        'template' => 'sizemap.templ',
        'outfile' => 'sizemap.html',
    );
}


sub make_comic {
    my ($width, $height) = @_;

    my $comic = MockComic::make_comic();
    $comic->{height} = $height;
    $comic->{width} = $width;
    return $comic;
}


sub fails_on_missing_configuration : Tests {
    eval {
        Comic::Out::Sizemap->new(
            'template' => '...',
        );
    };
    like($@, qr{\bSizemap\b}, 'should mention module');
    like($@, qr{\boutfile\b}i, 'should mention what is missing');

    eval {
        Comic::Out::Sizemap->new(
            'outfile' => {},
        );
    };
    like($@, qr{\bSizemap\b}, 'should mention module');
    like($@, qr{\btemplate\b}i, 'should mention what is missing');
}


sub sorting : Tests {
    my $a = make_comic(10, 100);
    my $b = make_comic(20, 90);
    my $c = make_comic(30, 80);

    is_deeply([$c, $b, $a], [sort Comic::Out::Sizemap::_by_height ($b, $a, $c)]);
    is_deeply([$a, $b, $c], [sort Comic::Out::Sizemap::_by_width ($b, $a, $c)]);
}


sub aggregate_sizes_none : Tests {
    my %aggregated = Comic::Out::Sizemap::_aggregate_comic_sizes();
    is_deeply(\%aggregated, {
        height => {
            min => 9999999,
            max => 0,
            avg => 0,
       },
        width => {
            min => 9999999,
            max => 0,
            avg => 0,
       },
    });

}


sub aggregate_sizes_one : Tests {
    my $comic = make_comic(100, 300);
    my %aggregated = Comic::Out::Sizemap::_aggregate_comic_sizes($comic);
    is_deeply(\%aggregated, {
        height => {
            min => 300,
            max => 300,
            avg => 300,
       },
        width => {
            min => 100,
            max => 100,
            avg => 100,
       },
    });
}


sub aggregate_sizes_many : Tests {
    my @comics = (
        make_comic(100, 500),
        make_comic(200, 600),
        make_comic(300, 400),
    );
    my %aggregated = Comic::Out::Sizemap::_aggregate_comic_sizes(@comics);
    is_deeply(\%aggregated, {
        height => {
            min => 400,
            max => 600,
            avg => 500,
       },
        width => {
            min => 100,
            max => 300,
            avg => 200,
        },
    });
}


sub aggregate_none : Tests {
    my %vars = $sizemap->_aggregate();

    is($vars{'minheight'}, 'n/a', 'min height');
    is($vars{'maxheight'}, 'n/a', 'max_height');
    is($vars{'avgheight'}, 'n/a', 'avg height');
    is($vars{'minwidth'}, 'n/a', 'min width');
    is($vars{'maxwidth'}, 'n/a', 'max width');
    is($vars{'avgwidth'}, 'n/a', 'avg width');
    like($vars{'svg'}, qr{<svg\s+[^>]+>}m, 'svg');
}


sub configure_scale : Tests {
    $sizemap = Comic::Out::Sizemap->new(
        'template' => 'sizemap.templ',
        'outfile' => 'sizemap.html',
        'scale' => 2.0,
    );
    my $comic = make_comic(500, 100);
    my %vars = $sizemap->_aggregate($comic);
    is($vars{'maxheight'}, 100, 'should have kept original max height');
    is($vars{'minheight'}, 100, 'should have kept original min height');
    is($vars{'avgheight'}, 100, 'should have kept original average height');
    is($vars{'maxwidth'}, 500, 'should have kept original max width');
    is($vars{'minwidth'}, 500, 'should have kept original min width');
    is($vars{'avgwidth'}, 500, 'should have kept original average width');
    like($vars{'svg'}, qr{<svg\b[^>]*\bwidth="1000"}m, 'svg element should have scaled width');
    like($vars{'svg'}, qr{<svg\s+[^>]*\bheight="200"}, 'svg element should have scaled height');
    like($vars{'svg'}, qr{<rect\b[^>]*\bwidth="1000"}m, 'rect element should have scaled width');
    like($vars{'svg'}, qr{<rect\s+[^>]*\bheight="200"}, 'rect element should have scaled height');
}


sub fails_if_configured_scale_is_not_numeric : Tests {
    eval {
        $sizemap = Comic::Out::Sizemap->new(
            'template' => 'sizemap.templ',
            'outfile' => 'sizemap.html',
            'scale' => 'whatever',
        );
    };
    like($@, qr{Sizemap\.scale}, 'should mention the configuration');
    like($@, qr{\bnumeric\b}, 'should say what is wrong');
}


sub configure_published_color : Tests {
    $sizemap = Comic::Out::Sizemap->new(
        'template' => 'sizemap.templ',
        'outfile' => 'sizemap.html',
        'published_color' => 'red',
    );
    my $comic = make_comic(500, 100);
    my %vars = $sizemap->_aggregate($comic);
    like($vars{'svg'}, qr{<rect\s+[^>]*style="[^"]*\bstroke:\s*red\b}, 'should have passed color');
}


sub configure_unpublished_color : Tests {
    $sizemap = Comic::Out::Sizemap->new(
        'template' => 'sizemap.templ',
        'outfile' => 'sizemap.html',
        'unpublished_color' => 'pink',
    );
    my $comic = make_comic(500, 100);
    $comic->{meta_data}->{published}->{when} = '3000-01-01';
    my %vars = $sizemap->_aggregate($comic);
    like($vars{'svg'}, qr{<rect\s+[^>]*style="[^"]*\bstroke:\s*pink\b}, 'should have passed color');
}


sub generate_all : Tests {
    MockComic::fake_file('sizemap.templ', '[% svg %]');

    $sizemap = Comic::Out::Sizemap->new(
        'template' => 'sizemap.templ',
        'outfile' => 'sizemap.html',
    );
    my $comic = make_comic(500, 100);
    $sizemap->generate_all($comic);

    MockComic::assert_wrote_file('sizemap.html', qr{<svg [^>]+>});
}
