use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub setup : Test(setup) {
    MockComic::set_up();
}


sub make_comic {
    my ($published_when, $published_where, $language) = @_;

    $language ||= $MockComic::ENGLISH;
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $language => 'Drinking beer',
        },
        $MockComic::PUBLISHED_WHEN => $published_when,
        $MockComic::PUBLISHED_WHERE => ($published_where || 'web'),
        $MockComic::MTIME => DateTime->new(year => 2016, month => 1, day => 1)->epoch,
    );
    $comic->{pngFile}{$language} = "drinking-beer.png";
    return $comic;
}


sub assert_wrote {
    my ($comic, $contentsExpected) = @_;

    $comic->_write_sitemap_xml_fragment($MockComic::ENGLISH);
    MockComic::assert_wrote_file(
        'generated/english/tmp/sitemap/drinking-beer.xml',
        $contentsExpected);
}


sub page : Tests {
    assert_wrote(make_comic('2016-01-01'),
        qr{<loc>https://beercomics.com/comics/drinking-beer.html</loc>}m);
}


sub last_modified : Tests {
    assert_wrote(make_comic('2016-01-01'),
        qr{<lastmod>2016-01-01</lastmod>}m);
}


sub image : Tests {
    assert_wrote(make_comic('2016-01-01'), 
        qr{<image:loc>https://beercomics.com/comics/drinking-beer.png</image:loc>}m);
}


sub image_title : Tests {
    assert_wrote(make_comic('2016-01-01'), 
        qr{<image:title>Drinking beer</image:title>}m);
}


sub image_license : Tests {
    assert_wrote(make_comic('2016-01-01'),
        qr{<image:license>https://beercomics.com/imprint.html</image:license>}m);
}


sub unpublished : Tests {
    assert_wrote(make_comic('3016-01-01')); # should not write anything
}


sub wrong_language : Tests {
    assert_wrote(make_comic('2016-01-01', 'web', 'Deutsch')); # should not write anything
}


sub not_on_my_page : Tests {
    assert_wrote(make_comic('2016-01-01', 'biermag', 'English')); # should nnot write anything
}
