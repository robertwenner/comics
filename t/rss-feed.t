use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub setup : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file('rss.templ', <<"RSS");
[% done = 0 %]
[% FOREACH c IN comics %]
[% NEXT IF notFor(c, 'English') %]
[% LAST IF done == max %]
[% done = done + 1 %]
<item>
<title>[% c.meta_data.title.English %]</title>
<link>https://beercomics.com/comics/[% c.htmlFile.English %]</link>
<pubDate>[% c.rfc822pubDate %]</pubDate>
</item>
[% END %]
RSS
}


sub make_comic {
    my ($title, $published) = @_;

    return MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => $title,
        },
        $MockComic::PUBLISHED_WHEN => $published
    );
}


sub assert_wrote {
    my ($count, $contentsExpected) = @_;

    Comic::export_rss_feed($count, 'rss.xml', ('English' => 'rss.templ'));
    MockComic::assert_wrote_file('generated/english/web/rss.xml', $contentsExpected);
}


sub no_comic : Test {
    Comic::export_rss_feed(10, 'rss.xml', ('English' => 'rss.templ'));
    MockComic::assert_didnt_write_in_file('rss.xml', qr{item});
}


sub one_comic : Test {
    make_comic('eins', '2016-01-01');
    my $item = qr{
        <item>\s*
        <title>eins</title>\s*
        <link>https://beercomics\.com/comics/eins\.html</link>\s*
        <pubDate>Fri,\s01\sJan\s2016\s00:00:00\s-0500</pubDate>\s*
        </item>}mx;
    assert_wrote(10, $item);
}


sub count_cut_off : Test {
    make_comic('eins', '2016-01-01');
    make_comic('zwei', '2016-01-02');
    make_comic('drei', '2016-01-03');
    my $item = qr{
        <item>\s*
        <title>drei</title>\s*
        <link>https://beercomics\.com/comics/drei\.html</link>\s*
        <pubDate>Sun,\s03\sJan\s2016\s00:00:00\s-0500</pubDate>\s*
        </item>}mx;
    assert_wrote(1, $item);

}


sub published_only : Test {
    make_comic('eins', '3016-01-01');
    make_comic('zwei', '2016-01-02');
    make_comic('drei', '3016-01-03');
    my $item = qr{
        <item>\s*
        <title>zwei</title>\s*
        <link>https://beercomics.com/comics/zwei.html</link>\s*
        <pubDate>Sat,\s02\sJan\s2016\s00:00:00\s-0500</pubDate>\s*
        </item>}mx;
    assert_wrote(1, $item);
}


sub order : Test {
    make_comic('eins', '2016-01-01');
    make_comic('zwei', '2016-01-02');
    make_comic('drei', '2016-01-03');
    my $items = qr{
        <item>\s*
        <title>drei</title>\s*
        <link>https://beercomics.com/comics/drei.html</link>\s*
        <pubDate>Sun,\s03\sJan\s2016\s00:00:00\s-0500</pubDate>\s*
        </item>\s*
        <item>\s*
        <title>zwei</title>\s*
        <link>https://beercomics.com/comics/zwei.html</link>\s*
        <pubDate>Sat,\s02\sJan\s2016\s00:00:00\s-0500</pubDate>\s*
        </item>\s*
        <item>\s*
        <title>eins</title>\s*
        <link>https://beercomics.com/comics/eins.html</link>\s*
        <pubDate>Fri,\s01\sJan\s2016\s00:00:00\s-0500</pubDate>\s*
        </item>}mx;
    assert_wrote(10, $items);
}


sub by_language : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier',
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
    );
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Beer',
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
    );

    MockComic::fake_file('de.templ', <<"RSS");
[% done = 0 %]
[% FOREACH c IN comics %]
[% NEXT IF notFor(c, 'Deutsch') %]
[% LAST IF done == max %]
[% done = done + 1 %]
<item>
<title>[% c.meta_data.title.Deutsch %]</title>
<link>https://biercomics.de/comics/[% c.htmlFile.Deutsch %]</link>
<pubDate>[% c.rfc822pubDate %]</pubDate>
</item>
[% END %]
RSS

    Comic::export_rss_feed(5, 'rss.xml', ('Deutsch' => 'de.templ', 'English' => 'rss.templ'));
    my $english = qr{<title>Beer</title>};
    my $deutsch = qr{<title>Bier</title>};
    MockComic::assert_wrote_file('generated/deutsch/web/rss.xml', $deutsch);
    MockComic::assert_didnt_write_in_file('generated/deutsch/web/rss.xml', $english);
    MockComic::assert_wrote_file('generated/english/web/rss.xml', $english);
    MockComic::assert_didnt_write_in_file('generated/english/web/rss.xml', $deutsch);
}


sub xml_special_characters : Tests {
    make_comic('&lt;Ale &amp; Lager&gt;', '2016-01-01');
    assert_wrote(10, qr{<title>&lt;Ale &amp; Lager&gt;</title>});
}


sub not_published_on_web : Test {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Bier in der Zeitung',
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01',,
        $MockComic::PUBLISHED_WHERE => 'tolle Zeitung');
    Comic::export_rss_feed(10, 'rss.xml', ('English' => 'rss.templ'));
    MockComic::assert_didnt_write_in_file('rss.xml', qr{item});
}
