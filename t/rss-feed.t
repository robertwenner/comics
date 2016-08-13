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
    my ($title, $published) = @_;

    return MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => $title,
        },
        $MockComic::PUBLISHED => $published
    );
}


sub assert_wrote {
    my ($count, $contentsExpected) = @_;

    Comic::export_rss_feed($count);
    MockComic::assert_wrote_file(
        'generated/english/tmp/rss.xml',
        $contentsExpected);
}


sub no_comic : Test {
    assert_wrote(3, undef);
}


sub one_comic : Test {
    make_comic('eins', '2016-01-01');
    assert_wrote(1, <<'XML');
<item>
<title>eins</title>
<link>https://beercomics.com/comics/eins.html</link>
<pubDate>Fri, 01 Jan 2016 00:00:00 -0500</pubDate>
</item>
XML
}


sub count_cut_off : Test {
    make_comic('eins', '2016-01-01');
    make_comic('zwei', '2016-01-02');
    make_comic('drei', '2016-01-03');
    assert_wrote(1, <<'XML');
<item>
<title>drei</title>
<link>https://beercomics.com/comics/drei.html</link>
<pubDate>Sun, 03 Jan 2016 00:00:00 -0500</pubDate>
</item>
XML
}


sub published_only : Test {
    make_comic('eins', '3016-01-01');
    make_comic('zwei', '2016-01-02');
    make_comic('drei', '3016-01-03');
    assert_wrote(1, <<'XML');
<item>
<title>zwei</title>
<link>https://beercomics.com/comics/zwei.html</link>
<pubDate>Sat, 02 Jan 2016 00:00:00 -0500</pubDate>
</item>
XML
}


sub order : Test {
    make_comic('eins', '2016-01-01');
    make_comic('zwei', '2016-01-02');
    make_comic('drei', '2016-01-03');
    assert_wrote(10, <<'XML');
<item>
<title>drei</title>
<link>https://beercomics.com/comics/drei.html</link>
<pubDate>Sun, 03 Jan 2016 00:00:00 -0500</pubDate>
</item>
<item>
<title>zwei</title>
<link>https://beercomics.com/comics/zwei.html</link>
<pubDate>Sat, 02 Jan 2016 00:00:00 -0500</pubDate>
</item>
<item>
<title>eins</title>
<link>https://beercomics.com/comics/eins.html</link>
<pubDate>Fri, 01 Jan 2016 00:00:00 -0500</pubDate>
</item>
XML
}


sub by_language : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier',
        },
        $MockComic::PUBLISHED => '2016-01-01',
    );
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Beer',
        },
        $MockComic::PUBLISHED => '2016-01-01',
    );

    Comic::export_rss_feed(5);
    MockComic::assert_wrote_file('generated/deutsch/tmp/rss.xml', <<'XML');
<item>
<title>Bier</title>
<link>https://biercomics.de/comics/bier.html</link>
<pubDate>Fri, 01 Jan 2016 00:00:00 -0500</pubDate>
</item>
XML
    MockComic::assert_wrote_file('generated/english/tmp/rss.xml', <<'XML');
<item>
<title>Beer</title>
<link>https://beercomics.com/comics/beer.html</link>
<pubDate>Fri, 01 Jan 2016 00:00:00 -0500</pubDate>
</item>
XML
}
