use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Out::HtmlComicPage;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file("de-comic.templ", "...");
    MockComic::fake_file("en-comic.templ", '[% FILTER html %][% comic.meta_data.title.$Language %][% END %]');
}


sub make_comic {
    my ($language, $title, $published_when, $published_where) = @_;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $language => $title },
        $MockComic::PUBLISHED_WHEN => $published_when,
        $MockComic::PUBLISHED_WHERE => $published_where || "web",
        $MockComic::SETTINGS => {
            'Domains' => {
                'English' => 'beercomics.com',
                'Deutsch' => 'biercomics.de',
            },
        },
    );
    # clear out some dummy values MockComic sets; the code under tests needs to provide them
    $comic->{url} = {};
    $comic->{href} = {};
    $comic->{urlUrlEncoded} = {};
    return $comic;
}


sub make_generator {
    my %templates = @_;
    my %options = (
        'outdir' => 'generated/web/',
        'template' => {
            'English' => 'en-comic.templ',
        },
    );
    foreach my $key (keys %templates) {
        $options{'template'}{$key} = $templates{$key};
    }
    return Comic::Out::HtmlComicPage->new(%options);
}


sub generate_everything {
    my ($hcp, @comics) = @_;

    foreach my $comic (@comics) {
        $hcp->generate($comic);
    }
    $hcp->generate_all(@comics);
}


sub fails_on_missing_configuration : Tests {
    eval {
        Comic::Out::HtmlComicPage->new();
    };
    like($@, qr{\bComic::Out::HtmlComicPage\b});

    eval {
        Comic::Out::HtmlComicPage->new(
            'template' => {},
        );
    };
    like($@, qr{\bComic::Out::HtmlComicPage\.outdir\b});

    eval {
        Comic::Out::HtmlComicPage->new(
            'outdir' => '/tmp',
        );
    };
    like($@, qr{\bComic::Out::HtmlComicPage\.template\b});
}


sub fails_if_no_template_for_language : Tests {
    my $comic = make_comic('English', 'Beer brewing', '2016-01-01');
    my $hcp = Comic::Out::HtmlComicPage->new(
        'outdir' => 'generated/web',
        'template' => {},
    );
    eval {
        $hcp->generate_all($comic);
    };
    like($@, qr{\btemplate\b});
    like($@, qr{\bEnglish\b});

    $hcp = Comic::Out::HtmlComicPage->new(
        'outdir' => 'generated/web',
        'template' => {
            'English' => '',
        },
    );
    eval {
        $hcp->generate_all($comic);
    };
    like($@, qr{\btemplate\b});
    like($@, qr{\bEnglish\b});
}


sub generates_html_page_and_href : Tests {
    my $comic = make_comic('English', 'Beer brewing', '2016-01-01');
    $comic->{baseName}{'English'} = "bass";
    my $hcp = make_generator();
    $hcp->generate($comic);
    is_deeply($comic->{url}, {'English' => 'https://beercomics.com/comics/bass.html'});
    $hcp->generate_all($comic);
    is_deeply($comic->{htmlFile}, {'English' => 'bass.html'}, 'wrong html file name');
    is_deeply($comic->{href}, {'English' => 'comics/bass.html'}, 'wrong href');
}


sub navigation_links_first : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    my $hcp = make_generator();
    generate_everything($hcp, $jan, $feb, $mar);

    is($jan->{'first'}{'English'}, 0, "Jan first");
    is($jan->{'prev'}{'English'}, 0, "Jan prev");
    is($jan->{'next'}{'English'}, "feb.html", "Jan next");
    is($jan->{'last'}{'English'}, "mar.html", "Jan last");
}


sub navigation_links_middle : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    my $hcp = make_generator();
    generate_everything($hcp, $jan, $feb, $mar);

    is($feb->{'first'}{'English'}, "jan.html", "Feb first");
    is($feb->{'prev'}{'English'}, "jan.html", "Feb prev");
    is($feb->{'next'}{'English'}, "mar.html", "Feb next");
    is($feb->{'last'}{'English'}, "mar.html", "Feb last");
}


sub navigation_links_last : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    my $hcp = make_generator();
    generate_everything($hcp, $jan, $feb, $mar);

    is($mar->{'first'}{'English'}, "jan.html", "Mar first");
    is($mar->{'prev'}{'English'}, "feb.html", "Mar prev");
    is($mar->{'next'}{'English'}, 0, "Mar next");
    is($mar->{'last'}{'English'}, 0, "Mar last");
}


sub skips_comic_not_published_on_my_page : Tests {
    my $comic = make_comic('English', 'Magazined!', '2016-01-01', 'some beer magazine');
    my $hcp = make_generator();
    is('Magazined!', $hcp->_do_export_html($comic, 'English', 'en-comic.templ'));
    generate_everything($hcp, $comic);
    MockComic::assert_didnt_write_in_file('generated/web/english/comics/magazined.html');
}


sub skips_comic_without_that_language : Tests {
    my $jan = make_comic('English', 'jan', '2016-01-01');
    my $feb = make_comic('Deutsch', 'feb', '2016-02-01');
    my $mar = make_comic('English', 'mar', '2016-03-01');

    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $jan, $feb, $mar);

    is($jan->{'first'}{'English'}, 0, "Jan first");
    is($jan->{'prev'}{'English'}, 0, "Jan first");
    is($jan->{'next'}{'English'}, 'mar.html', "Jan next");
    is($jan->{'last'}{'English'}, 'mar.html', "Jan last");

    is($mar->{'first'}{'English'}, 'jan.html', "Mar first");
    is($mar->{'prev'}{'English'}, 'jan.html', "Mar first");
    is($mar->{'next'}{'English'}, 0, "Mar next");
    is($mar->{'last'}{'English'}, 0, "Mar last");

    is($feb->{'first'}{'Deutsch'}, 0, "Feb first");
    is($feb->{'prev'}{'Deutsch'}, 0, "Feb prev");
    is($feb->{'next'}{'Deutsch'}, 0, "Feb next");
    is($feb->{'last'}{'Deutsch'}, 0, "Feb last");
}


sub skips_comic_without_published_date : Tests {
    my $comic = make_comic('English', 'not yet', '');
    my $hcp = make_generator();
    generate_everything($hcp, $comic);
    MockComic::assert_wrote_file('generated/web/english/comics/not-yet.html', undef);
}


sub skips_comic_in_far_future : Tests {
    my $not_yet = make_comic('English', 'not yet', '2200-01-01');
    my $hcp = make_generator();
    generate_everything($hcp, $not_yet);
    MockComic::assert_wrote_file('generated/web/english/comics/not-yet.html', undef);
}


sub includes_comic_for_next_friday : Tests {
    #       May 2016
    #  Su Mo Tu We Th Fr Sa
    #   1  2  3  4  5  6  7
    #   8  9 10 11 12 13 14
    #  15 16 17 18 19 20 21
    #  22 23 24 25 26 27 28
    #  29 30 31
    MockComic::fake_now(DateTime->new(year => 2016, month => 5, day => 1));
    my $comic = make_comic('English', 'next Friday', '2016-05-01');
    my $hcp = make_generator();
    generate_everything($hcp, $comic);
    MockComic::assert_wrote_file('generated/web/english/comics/next-friday.html',
        qr{next Friday});
}


sub separate_navs_for_archive_and_backlog : Tests {
    my $a1 = make_comic('Deutsch', 'arch1', '2016-01-01');
    my $a2 = make_comic('Deutsch', 'arch2', '2016-01-02');
    my $b1 = make_comic('Deutsch', 'back1', '2222-01-01');
    my $b2 = make_comic('Deutsch', 'back2', '2222-01-02');

    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $a1, $a2, $b1, $b2);

    is($a1->{'prev'}{'Deutsch'}, 0, "arch1 should have no prev");
    is($a1->{'next'}{'Deutsch'}, "arch2.html", "arch1 next should be arch2");
    is($a1->{'first'}{'Deutsch'}, 0, "arch1 should have no first");
    is($a1->{'last'}{'Deutsch'}, "arch2.html", "arch1 last should be arch2");

    is($a2->{'prev'}{'Deutsch'}, "arch1.html", "arch2 prev should be arch1");
    is($a2->{'next'}{'Deutsch'}, 0, "arch2 should not have a next");
    is($a2->{'first'}{'Deutsch'}, "arch1.html", "arch2 first should be arch1");
    is($a2->{'last'}{'Deutsch'}, 0, "arch2 should not have a last");

    is($b1->{'prev'}{'Deutsch'}, 0, "back1 should not have a prev");
    is($b1->{'next'}{'Deutsch'}, "back2.html", "back1 next should be back2");
    is($b1->{'first'}{'Deutsch'}, 0, "back1 should not have a first");
    is($b1->{'last'}{'Deutsch'}, "back2.html", "back1 last should be back2");

    is($b2->{'next'}{'Deutsch'}, 0, "back2 should not have a next");
    is($b2->{'prev'}{'Deutsch'}, "back1.html", "back2 prev should be back1");
    is($b2->{'first'}{'Deutsch'}, "back1.html", "back2 first should be back1");
    is($b2->{'last'}{'Deutsch'}, 0, "back2 should not have a last");
}


sub nav_template : Tests {
    my $one = MockComic::make_comic(
        $MockComic::TITLE => { 'English' => 'One' },
        $MockComic::PUBLISHED_WHEN => '2015-12-01',
    );
    my $two = MockComic::make_comic(
        $MockComic::TITLE => { 'English' => 'Two' },
        $MockComic::PUBLISHED_WHEN => '2015-12-02',
    );
    MockComic::fake_file('en-comic.templ', <<'XML');
    [% IF comic.first.English %]
        <a href="[% indexAdjust %][% comic.first.English %]">First</a>
    [% END %]
XML
    my $hcp = make_generator();
    generate_everything($hcp, $one, $two);
    my $exported = $hcp->_do_export_html($two, 'English', 'en-comic.templ');
    like($exported, qr{<a\s+href="comics/one\.html">First</a>});
}


sub language_links_none : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Deutsch' => 'Bier trinken',
        }
    );
    MockComic::fake_file('de-comic.templ', <<'XML');
[% FOREACH l IN languages %]
    <a hreflang="[% languagecodes.$l %]" href="[% languageurls.$l %]" title="[% comic.meta_data.title.$l %]">[% l %]</a>
[% END %]
XML
    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $comic);
    MockComic::assert_wrote_file('generated/web/deutsch/comics/bier-trinken.html', qr{^\s*$});
}


sub language_links : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
        }
    );
    MockComic::fake_file('de-comic.templ', <<'XML');
[% FOREACH l IN languages %]
    <a hreflang="[% languagecodes.$l %]" href="[% languageurls.$l %]" title="[% comic.meta_data.title.$l %]">[% l %]</a>
[% END %]
XML
    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $comic);
    my $exported = $hcp->_do_export_html($comic, 'Deutsch', 'de-comic.templ');
    like($exported, qr{href="https://beercomics\.com/comics/drinking-beer\.html"},
        'URL not found');
    like($exported, qr{>English</a>}, 'Language code not found');
    like($exported, qr{hreflang="en"}, 'hreflang not found');
    like($exported, qr{title="Drinking beer"}, 'title not found');
    unlike($hcp->_do_export_html($comic, 'Deutsch', 'de-comic.templ'),
        qr{https://biercomics\.de"}, 'Should not link to self');
}


sub language_links_alternate : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
        }
    );
    MockComic::fake_file('de-comic.templ', <<'XML');
[% FOREACH l IN languages %]
<link rel="alternate" hreflang="[% languagecodes.$l %]" href="[% languageurls.$l %]"/>
[% END %]
XML
    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $comic);
    my $exported = $hcp->_do_export_html($comic, 'Deutsch', 'de-comic.templ');
    like($exported, qr{href="https://beercomics\.com/comics/drinking-beer\.html"},
        'URL not found');
    like($exported, qr{hreflang="en"}, 'hreflang not found');
    unlike($hcp->_do_export_html($comic, 'Deutsch', 'de-comic.templ'),
        qr{https://biercomics\.de"}, 'Should not link to self');
}


sub language_link_index_html : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
        }
    );
    MockComic::fake_file('de-comic.templ', <<'XML');
[% FOREACH l IN languages %]
<link rel="alternate" hreflang="[% languagecodes.$l %]" href="[% languageurls.$l %]"/>
[% END %]
XML
    $comic->{isLatestPublished} = 1;
    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $comic);
    my $exported = $hcp->_do_export_html($comic, 'Deutsch', 'de-comic.templ');
    like($exported, qr{\s+hreflang="en"\s+href="https://beercomics.com/"}, 'wrong hreflang');
}


sub fb_open_graph : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Deutsch' => 'Bier trinken',
        },
        $MockComic::DESCRIPTION => {
            'Deutsch' => 'Paul und Max \"gehen\" Bier trinken.',
        },
    );
    MockComic::fake_file('de-comic.templ', <<'XML');
<meta property="og:url" content="[% comic.url.$Language %]"/>
<meta property="og:image:secure_url" content="[% comic.url.$Language %]"/>
<meta property="og:type" content="article"/>
<meta property="og:title" content="[% comic.meta_data.title.$Language %]"/>
<meta property="og:site_name" content="Biercomics"/>
<meta property="og:description" content="[% FILTER html %][% comic.meta_data.description.$Language %][% END %]"/>
<meta property="og:locale" content="de"/>
<meta property="og:image:type" content="image/png"/>
<meta property="og:image:height" content="[% comic.height %]"/>
<meta property="og:image:width" content="[% comic.width %]"/>
<meta property="og:article:published" content="[% comic.meta_data.published.when %]"/>
<meta property="og:article:modified" content="[% comic.modified %]"/>
<meta property="og:article:author" content="Robert Wenner"/>
<meta property="og:article:tag" content="[% USE JSON %][% comic.meta_data.tags.$Language.json %]"/>
<meta property="og:website" content="https://biercomics.de"/>
[% FOREACH l IN languages %]
<!-- This is pointless because you cannot specify the other language URL here.
Instead Facebook will just add a URL parameter for the language and hit the
same page again. I guess that is a limitation from their simplistic key/value
properties.
https://developers.facebook.com/docs/opengraph/guides/internationalization/?_fb_noscript=1#objects
-->
<meta property="og:locale:alternate" content="[% languagecodes.$l %]"/>
[% END %]
XML
    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $comic);
    my $exported = $hcp->_do_export_html($comic, 'Deutsch', 'de-comic.templ');
    like($exported, qr{<meta property="og:url" content="https://biercomics\.de/comics/bier-trinken\.html"/>},
        'URL not found');
    like($exported, qr{<meta property="og:title" content="Bier trinken"/>},
        'Title not found');
    like($exported, qr{<meta property="og:description" content="Paul und Max &quot;gehen&quot; Bier trinken."/>},
        'Description not found');
}


sub index_html_with_canonical_link : Tests {
    MockComic::fake_file('backlog.templ', '');
    MockComic::fake_file('archive.templ', '');
    MockComic::fake_file('comic.templ', '[% canonicalUrl %]');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { 'English' => "Beer" },
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
    );
    my $hcp = make_generator('English' => 'comic.templ');
    $hcp->generate($comic);
    is($hcp->_do_export_html($comic, 'English', 'comic.templ'),
        'https://beercomics.com/comics/beer.html');

    $hcp->_export_language_html($comic, 'English', 'comic.templ');
    MockComic::assert_wrote_file('english/web/comics/ale-lager.html', qr{^\s*$}m);

    $hcp->export_index(($comic));
    MockComic::assert_wrote_file('generated/web/english/index.html',
        'https://beercomics.com/');
}


sub index_html_does_not_break_perm_link : Tests {
    MockComic::fake_file('comic.templ', '[% comic.url.$Language %]');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => "Beer",
            'Deutsch' => "Bier",
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
    );

    my $hcp = make_generator('Deutsch' => 'de-comic.templ');
    generate_everything($hcp, $comic);
    $hcp->_do_export_html($comic, 'English', 'comic.templ');

    is_deeply({
            'English' => 'https://beercomics.com/comics/beer.html',
            'Deutsch' => 'https://biercomics.de/comics/bier.html',
        },
        $comic->{url});
}


sub index_html_hookup : Tests {
    my $comic = make_comic('English', 'Beer', '2016-01-01');

    my $hcp = make_generator();
    generate_everything($hcp, $comic);

    ok($comic->{isLatestPublished}, 'Should have exported index.html');
    MockComic::assert_wrote_file('generated/web/english/comics/beer.html', 'Beer');
    MockComic::assert_wrote_file('generated/web/english/index.html', 'Beer');
}


sub includes_references: Tests {
    my $comic = make_comic('English', 'Beer', '2016-01-01');
    $comic->{htmllink} = { 'English' => 'see.html' };

    my $hcp = make_generator();
    my %vars = $hcp->_set_vars($comic, 'English');

    is_deeply($vars{'see'}, { 'English' => 'see.html' }, 'wrong see reference');
}


sub provides_empty_references_hash_if_no_real_references : Tests {
    my $comic = make_comic('English', 'Beer', '2016-01-01');

    my $hcp = make_generator();
    my %vars = $hcp->_set_vars($comic, 'English');

    is_deeply($vars{'see'}, {}, 'should set see to an empty hash');
}
