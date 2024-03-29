use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use DateTime;
use Comic::Out::Feed;


__PACKAGE__->runtests() unless caller;

my $feed;


sub setup : Test(setup) {
    MockComic::set_up();

    MockComic::fake_now(DateTime->new(year => 2021, month => 2, day => 28, hour => 18, minute => 03, second => 10));
    no warnings qw/redefine/;
    *Comic::Out::Feed::_get_tz = sub {
        return "-0400";
    };

    use warnings;

    my $SIMPLE_TEMPLATE = <<'TEMPL';
[% FOREACH c IN comics %]
[% c.meta_data.title.English %]
[% END %]
TEMPL
    MockComic::fake_file('simple.templ', $SIMPLE_TEMPLATE);

    $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "Atom" => {
            "template" => "simple.templ"
        }
    );
}


sub make_comic {
    my ($title, $published) = @_;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => $title,
        },
        $MockComic::PUBLISHED_WHEN => $published
    );
    $comic->{htmlFile}{$MockComic::ENGLISH} = "$title.html";
    $comic->{url}{$MockComic::ENGLISH} = "https://beercomics.com/comics/$title.html";
    $comic->{href}{$MockComic::ENGLISH} = "comics/$title.html";
    return $comic;
}


sub no_output_directory_configured : Tests {
    eval {
        Comic::Out::Feed->new(
            "Atom" => {
                "template" => "simple.templ"
            }
        );
    };
    like($@, qr{Comic::Out::Feed}, 'should mention module');
    like($@, qr{outdir}i, 'should mention problem');
}


sub no_template_configured_at_all : Tests {
    my $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web",
        "Atom" => {
            "outfile" => "rss.xml"
        },
    );
    my $comic = make_comic('one', '2016-01-01');
    eval {
        $feed->generate_all($comic);
    };
    like($@, qr{no Atom template}i);
}


sub no_template_configured_for_language : Tests {
    my $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web",
        "Atom" => {
            "template" => {}
        }
    );
    my @comics = (make_comic('one', '2016-01-01'));
    eval {
        $feed->generate_all(@comics);
    };
    like($@, qr{No Atom template}i, 'should mention problem');
    like($@, qr{English}, 'should mention language');
}


sub bad_template_for_all_languages : Tests {
    my $comic = make_comic('one', '2016-01-01');
    my $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web",
        "Atom" => {
            "template" => $comic
        },
    );
    eval {
        $feed->generate_all($comic);
    };
    like($@, qr{Bad Atom template}i, 'should mention problem');
}


sub bad_template_for_one_language : Tests {
    my $comic = make_comic('one', '2016-01-01');
    my $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web",
        "Atom" => {
            "template" => {
                "English" => $comic,
            },
        },
    );
    eval {
        $feed->generate_all($comic);
    };
    like($@, qr{Bad Atom template}i, 'should mention problem');
    like($@, qr{English}, 'should mention language');
}


sub no_comics : Tests {
    $feed->generate_all();
    MockComic::assert_didnt_write_in_file('generated/web/english/test.xml');
}


sub all_comics_filtered : Tests {
    my $comic = make_comic('one', '3000-01-01');
    $feed->generate_all($comic);
    MockComic::assert_wrote_file('generated/web/english/atom.xml', '');
}


sub one_comic : Tests {
    my $comic = make_comic('one', '2016-01-01');

    $feed->generate_all($comic);
    MockComic::assert_wrote_file('generated/web/english/atom.xml', qr{^\s*one\s*$}m);
}


sub published_only : Tests {
    my @comics = (
        make_comic('one', '3016-01-01'),
        make_comic('two', '2016-01-02'),
        make_comic('three', '3016-01-03'),
    );

    $feed->generate_all(@comics);
    MockComic::assert_wrote_file('generated/web/english/atom.xml', qr{^\s*two\s*$}m);
}


sub orders_from_latest_to_oldest : Tests {
    my @comics = (
        make_comic('one', '2016-01-01'),
        make_comic('two', '2016-01-02'),
        make_comic('three', '2016-01-03'),
    );

    $feed->generate_all(@comics);
    MockComic::assert_wrote_file('generated/web/english/atom.xml', qr{^\s*three\s*two\s*one\s*$}m);
}


sub templates_by_language : Tests {
    my @comics = (
        MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::DEUTSCH => 'Bier',
                $MockComic::ENGLISH => 'Beer',
            },
            $MockComic::PUBLISHED_WHEN => '2016-01-01',
        ),
    );
    foreach my $lang ("DE", "EN") {
        MockComic::fake_file("$lang.templ", <<"TEMPL");
[% FOREACH c IN comics %]
$lang: [% c.meta_data.title.\$Language %]
[% END %]
TEMPL
    }
    $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "RSS" => {
            "template" => {
                "English" => "EN.templ",
                "Deutsch" => "DE.templ",
            },
            "outfile" => "myfeed.xml",
        },
    );

    $feed->generate_all(@comics);
    MockComic::assert_wrote_file("generated/web/deutsch/myfeed.xml", qr{^DE: Bier\s*$"}m);
    MockComic::assert_wrote_file("generated/web/english/myfeed.xml", qr{^EN: Beer\s*$"}m);
}


sub provides_not_for_function : Tests {
    my $templ = << 'TEMPL';
[% FOREACH c IN comics %]
    [% IF NOT notFor(c, "web", "English") %]
        blah
    [% END %]
[% END %]
TEMPL
    MockComic::fake_file("notFor.templ", $templ);
    $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "Atom" => {
            "template" => "notFor.templ",
        },
    );
    my @comics = (make_comic('one', '2016-01-01'));

    $feed->generate_all(@comics);
    MockComic::assert_wrote_file('generated/web/english/atom.xml', qr{^\s*blah\s*$}m);
}


sub proviedes_max_item_count : Tests {
    MockComic::fake_file('test.templ', '[% max %]');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::DESCRIPTION => {'English' => 'Drinking beer'});
    $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "Atom" => {
            "template" => "test.templ",
            "max" => 1234,
        }
    );

    $feed->generate_all(($comic));
    MockComic::assert_wrote_file('generated/web/english/atom.xml', "1234");
}


sub provides_updated_timestamp : Tests {
    MockComic::fake_file('test.templ', '[% updated %]');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::DESCRIPTION => {'English' => 'Drinking beer'});
    $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "Atom" => {
            "template" => "test.templ"
        }
    );

    $feed->generate_all(($comic));
    MockComic::assert_wrote_file('generated/web/english/atom.xml', qr{^\s*2021-02-28T18:03:10-04:00\s*}m);
}


sub provides_png_size : Tests {
    MockComic::fake_file('test.templ', <<"ATOM");
[% FOREACH c IN comics %]
[% c.pngSize.English %]
[% END %]
ATOM
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::DESCRIPTION => {'English' => 'Drinking beer'});
    $comic->{pngSize}->{English} = 1024;
    $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "Atom" => {
            "template" => "test.templ"
        }
    );
    $feed->generate_all(($comic));
    MockComic::assert_wrote_file('generated/web/english/atom.xml', qr{^\s*1024\s*}m);
}


sub real_world_rss : Tests {
    MockComic::fake_file('rss.templ', <<"RSS");
[% done = 0 %]
[% FOREACH c IN comics %]
    [% NEXT IF notFor(c, 'web', 'English') %]
    [% LAST IF done == max %]
    [% done = done + 1 %]
    <item>
        <title>[% FILTER html %][% c.meta_data.title.English %][% END %]</title>
        <link>https://beercomics.com/comics/[% c.htmlFile.English %]</link>
        <pubDate>[% c.rfc822pubDate %]</pubDate>
    </item>
[% END %]
RSS
    my $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "RSS"=> {
            "template" => "rss.templ"
        }
    );

    my @comics = (make_comic('one', '2016-01-01'));
    $feed->generate_all(@comics);

    my $item = qr{
        <item>\s*
        <title>one</title>\s*
        <link>https://beercomics\.com/comics/one\.html</link>\s*
        <pubDate>Fri,\s01\sJan\s2016\s00:00:00\s-0500</pubDate>\s*
        </item>}mx;
    MockComic::assert_wrote_file('generated/web/english/rss.xml', $item);
}


sub real_world_atom : Tests {
    MockComic::fake_file('atom.templ', <<"ATOM");
[% FOREACH c IN comics %]
    [% NEXT IF notFor(c, "web", "English") %]
    <entry>
        <title>[% FILTER html %][% c.meta_data.title.English %][% END %]</title>
        <link href="https://beercomics.com/[% c.href.English %]"/>
        <published>[% c.rfc3339pubDate %]</published>
    </entry>
[% END %]
ATOM
    my $feed = Comic::Out::Feed->new(
        "outdir" => "generated/web/",
        "Atom" => {
            "template" => "atom.templ"
        }
    );
    my @comics = (make_comic('one', '2016-01-01'));
    $feed->generate_all(@comics);

    my $item = qr{
        <entry>\s*
        <title>one</title>\s*
        <link\shref="https://beercomics\.com/comics/one\.html"/>\s*
        <published>2016-01-01T00:00:00-05:00</published>\s*
        </entry>}mx;
    MockComic::assert_wrote_file('generated/web/english/atom.xml', $item);
}
