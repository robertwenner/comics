use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Out::Sitemap;

__PACKAGE__->runtests() unless caller;


my $sitemap;


sub setup : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file('templates/english/sitemap-xml.templ', <<'SITEMAP');
    [% FOREACH c IN comics %]
    [% NEXT IF notFor(c, 'web', 'English') %]
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
    [% NEXT IF notFor(c, 'web', 'Deutsch') %]
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
    $sitemap = Comic::Out::Sitemap->new(
        'template' => {
            'English' => 'templates/english/sitemap-xml.templ',
            'Deutsch' => 'templates/deutsch/sitemap-xml.templ',
        },
        'outfile' => {
            'English' => 'generated/english/web/sitemap.xml',
            'Deutsch' => 'generated/deutsch/web/sitemap.xml',
        },
    );
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
        $MockComic::MTIME => { 'some_comic.svg' => 1451624400 }, # 2016-01-01 00:00:00 -05:00
    );
    $comic->{pngFile}{$language} = "drinking-beer.png";
    $comic->{htmlFile}{$language} = "drinking-beer.html";
    return $comic;
}


sub assert_wrote {
    my ($comic, $contentsExpected) = @_;

    $sitemap->generate_all($comic);
    MockComic::assert_wrote_file(
        'generated/english/web/sitemap.xml',
        $contentsExpected);
}


sub assert_wrote_no_comic {
    my ($comic) = @_;

    $sitemap->generate_all($comic);
    MockComic::assert_didnt_write_in_file(
        'generated/english/web/sitemap.xml',
        qr{<image:image>}m);
}


sub fails_on_missing_configuration : Tests {
    eval {
        Comic::Out::Sitemap->new(
            'template' => {},
        );
    };
    like($@, qr{\bSitemap\b}, 'should mention module');
    like($@, qr{\boutfile\b}i, 'should mention what is missing');

    eval {
        Comic::Out::Sitemap->new(
            'outfile' => {},
        );
    };
    like($@, qr{\bComic::Out::Sitemap\b}, 'should mention module');
    like($@, qr{\btemplate\b}i, 'should mention what is missing');
}


sub fails_on_missing_template_for_language_configuration : Tests {
    $sitemap = Comic::Out::Sitemap->new(
        'template' => {},
        'outfile' => {
            'English' => 'web',
        },
    );
    eval {
        $sitemap->generate_all(make_comic('2016-01-01'));
    };
    like($@, qr{\bEnglish\b}, 'should mention language');
    like($@, qr{\btemplate\b}i, 'should mention what is missing');
}


sub fails_on_missing_outfile_for_language_configuration : Tests {
    $sitemap = Comic::Out::Sitemap->new(
        'template' => {
            'English' => 'templates/english/sitemap-xml.templ',
        },
        'outfile' => {},
    );
    eval {
        $sitemap->generate_all(make_comic('2016-01-01'));
    };
    like($@, qr{\bEnglish\b}, 'should mention language');
    like($@, qr{\btemplate\b}i, 'should mention what is missing');
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
    my $comic = make_comic('2016-01-01', 'web', 'Deutsch');
    assert_wrote_no_comic($comic);
    ok($comic->not_published_on_in('web', 'English'));
    ok(!$comic->not_published_on_in('web', 'Deutsch'));
}


sub not_on_my_page : Tests {
    my $comic = make_comic('2016-01-01', 'biermag', 'English');
    assert_wrote_no_comic($comic);
    ok($comic->not_published_on_in('web', 'English'));
}


sub encodes_xml_special_characters : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => '&lt;Ale &amp; Lager&gt;',
        },
    );
    $comic->{htmlFile}{English} = "ale__lager.html";
    $comic->{pngFile}{English} = 'ale__lager.png';
    assert_wrote($comic, qr{<image:title>&lt;Ale &amp; Lager&gt;</image:title>}m);
}


sub no_relative_paths : Tests {
    assert_wrote(make_comic('2016-01-01', 'Beer', 'English'), qr{(?!generated)}m);
}
