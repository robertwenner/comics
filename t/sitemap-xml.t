use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub setup : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file('templates/english/sitemap-xml.templ', <<'SITEMAP');
    [% FOREACH c IN comics %]
    [% NEXT IF notFor(c, 'English') %]
    <url>
        <loc>https://beercomics.com/comics/[% c.htmlFile.English %]</loc>
        <image:image>
            <image:loc>https://beercomics.com/comics/[% c.pngFile.English %]</image:loc>
            <image:title>[% FILTER html %][% c.meta_data.title.English %][% END %]</image:title>
            <image:license>https://beercomics.com/imprint.html</image:license>
        </image:image>
        <lastmod>[% c.modified %]</lastmod>
    </url>
    [% END %]
SITEMAP
    MockComic::fake_file('templates/deutsch/sitemap-xml.templ', <<'SITEMAP');
    [% FOREACH c IN comics %]
    [% NEXT IF notFor(c, 'Deutsch') %]
    <url>
        <loc>https://biercomics.de/comics/[% c.htmlFile.Deutsch %]</loc>
        <image:image>
            <image:loc>https://biercomics.de/comics/[% c.pngFile.Deutsch %]</image:loc>
            <image:title>[% FILTER html %][% c.meta_data.title.Deutsch %][% END %]</image:title>
            <image:license>https://biercomics.de/imprint.html</image:license>
        </image:image>
        <lastmod>[% c.modified %]</lastmod>
    </url>
    [% END %]
SITEMAP
    MockComic::fake_file('templates/deutsch/comic-page.templ', '...');
    MockComic::fake_file('templates/english/comic-page.templ', '...');
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
        $MockComic::MTIME => DateTime->new(
            year => 2016, month => 1, day => 1, time_zone => '-05:00')->epoch,
    );
    $comic->{pngFile}{$language} = "drinking-beer.png";
    return $comic;
}


sub assert_wrote {
    my ($comic, $contentsExpected) = @_;

    Comic::export_all_html({
        'English' => 'templates/english/comic-page.templ',
        'Deutsch' => 'templates/deutsch/comic-page.templ',
    },
    {
        'English' => 'templates/english/sitemap-xml.templ',
        'Deutsch' => 'templates/deutsch/sitemap-xml.templ',
    },
    {
        'English' => 'generated/english/web/sitemap.xml',
        'Deutsch' => 'generated/deutsch/web/sitemap.xml',
    });
    MockComic::assert_wrote_file(
        'generated/english/web/sitemap.xml',
        $contentsExpected);
}


sub assert_wrote_no_comic {
    my ($comic) = @_;

    Comic::export_all_html({
        'English' => 'templates/english/comic-page.templ',
        'Deutsch' => 'templates/deutsch/comic-page.templ',
    },
    {
        'English' => 'templates/english/sitemap-xml.templ',
        'Deutsch' => 'templates/deutsch/sitemap-xml.templ',
    },
    {
        'English' => 'generated/english/web/sitemap.xml',
        'Deutsch' => 'generated/deutsch/web/sitemap.xml',
    });
    MockComic::assert_didnt_write_in_file(
        'generated/english/web/sitemap.xml',
        qr{<image:image>}m);
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


sub future_published_date : Tests {
    assert_wrote_no_comic(make_comic('3016-01-01'));
}


sub no_published_date : Tests {
    assert_wrote_no_comic(make_comic(''));
}


sub wrong_language : Tests {
    assert_wrote_no_comic(make_comic('2016-01-01', 'web', 'Deutsch'));
}


sub not_on_my_page : Tests {
    assert_wrote_no_comic(make_comic('2016-01-01', 'biermag', 'English'));
}


sub encodes_xml_special_characters : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => '&lt;Ale &amp; Lager&gt;',
        },
    );
    assert_wrote($comic, qr{<image:title>&lt;Ale &amp; Lager&gt;</image:title>}m);
}


sub no_relative_paths : Tests {
    assert_wrote(make_comic('2016-01-01', 'Beer', 'English'), qr{(?!generated)}m);
}
