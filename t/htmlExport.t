use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub make_comic {
    my ($language, $title, $published) = @_;

    return MockComic::make_comic(
        $MockComic::TITLE => { $language => $title },
        $MockComic::PUBLISHED => $published);
}


sub languages_one : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { 'English' => 'Drinking beer' }
    );
    is_deeply([$comic->_languages()], ['English']);
}


sub languages_many : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
            'Español' => 'Tomar cerveca',
        }
    );
    is_deeply([sort $comic->_languages()], ['Deutsch', 'English', 'Español']);
}


sub languages_none : Tests {
    no warnings 'redefine';
    local *Comic::_slurp = sub {
        return <<'XML';
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg">
  <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{
            "title" : {}
        }</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
XML
    };
    my $comic = new Comic();
    is_deeply([sort $comic->_languages()], []);
    $comic->export_all_html();
    ok(1); # Would have failed above
}


sub navigation_links_first : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    Comic::export_all_html();

    is($jan->{'first'}{'English'}, 0, "Jan first");
    is($jan->{'prev'}{'English'}, 0, "Jan prev");
    is($jan->{'next'}{'English'}, "feb.html", "Jan next");
    is($jan->{'last'}{'English'}, "mar.html", "Jan last");
}


sub navigation_links_middle : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    Comic::export_all_html();

    is($feb->{'first'}{'English'}, "jan.html", "Feb first");
    is($feb->{'prev'}{'English'}, "jan.html", "Feb prev");
    is($feb->{'next'}{'English'}, "mar.html", "Feb next");
    is($feb->{'last'}{'English'}, "mar.html", "Feb last");
}


sub navigation_links_last : Tests {
    my $jan = make_comic('English', 'Jan', '2016-01-01');
    my $feb = make_comic('English', 'Feb', '2016-02-01');
    my $mar = make_comic('English', 'Mar', '2016-03-01');

    Comic::export_all_html();

    is($mar->{'first'}{'English'}, "jan.html", "Mar first");
    is($mar->{'prev'}{'English'}, "feb.html", "Mar prev");
    is($mar->{'next'}{'English'}, 0, "Mar next");
    is($mar->{'last'}{'English'}, 0, "Mar last");
}


sub ignores_unknown_language : Test {
    my $comic = make_comic('English', 'Jan', '2016-01-01'),
    Comic::export_all_html();
    is($comic->{pref}, undef);
}


sub skips_comic_without_that_language : Tests {
    my $jan = make_comic('English', 'jan', '2016-01-01');
    my $feb = make_comic('Deutsch', 'feb', '2016-02-01');
    my $mar = make_comic('English', 'mar', '2016-03-01');

    Comic::export_all_html();

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


sub skips_comic_without_published_date : Test {
    make_comic('English', 'not yet', '');
    Comic::export_all_html();
    is_deeply(\@MockComic::exported, ['not yet']);
}


sub skips_comic_in_far_future : Tests {
    my $not_yet = make_comic('English', 'not yet', '2200-01-01');
    Comic::export_all_html();
    is_deeply(\@MockComic::exported, ['not yet']);
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
    make_comic('English', 'next Friday', '2016-05-01');
    Comic::export_all_html();
    is_deeply(\@MockComic::exported, ['next Friday']);
}


sub separate_navs_for_archive_and_backlog : Tests {
    my $a1 = make_comic('Deutsch', 'arch1', '2016-01-01');
    my $a2 = make_comic('Deutsch', 'arch2', '2016-01-02');
    my $b1 = make_comic('Deutsch', 'back1', '2222-01-01');
    my $b2 = make_comic('Deutsch', 'back2', '2222-01-02');
    Comic::export_all_html();

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


sub language_links_none : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Deutsch' => 'Bier trinken',
        }
    );
    MockComic::fake_file('web/deutsch/comic-page.templ', <<'XML');
[% FOREACH l IN languages %]
    <a hreflang="[% languagecodes.$l %]" href="[% languageurls.$l %]" title="[% languagetitles.$l %]">[% l %]</a>
[% END %]
XML
    Comic::export_all_html();
    MockComic::assert_wrote_file('generated/deutsch/web/comics/bier-trinken.html', qr{^\s*$});
}


sub language_links : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
        }
    );
    MockComic::fake_file('web/deutsch/comic-page.templ', <<'XML');
[% FOREACH l IN languages %]
    <a hreflang="[% languagecodes.$l %]" href="[% languageurls.$l %]" title="[% languagetitles.$l %]">[% l %]</a>
[% END %]
XML
    Comic::export_all_html();
    my $exported = $comic->_do_export_html('Deutsch');
    like($exported, qr{href="https://beercomics\.com/comics/drinking-beer\.html"},
        'URL not found');
    like($exported, qr{>English</a>}, 'Language code not found');
    like($exported, qr{hreflang="en"}, 'hreflang not found');
    like($exported, qr{title="Drinking beer"}, 'title not found');
    unlike($comic->_do_export_html('Deutsch'), qr{https://biercomics\.de"},
        'Should not link to self');
}


sub language_links_alternate : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
        }
    );
    MockComic::fake_file('web/deutsch/comic-page.templ', <<'XML');
[% FOREACH l IN languages %]
<link rel="alternate" hreflang="[% languagecodes.$l %]" href="[% languageurls.$l %]"/>
[% END %]
XML
    Comic::export_all_html();
    my $exported = $comic->_do_export_html('Deutsch');
    like($exported, qr{href="https://beercomics\.com/comics/drinking-beer\.html"},
        'URL not found');
    like($exported, qr{hreflang="en"}, 'hreflang not found');
    unlike($comic->_do_export_html('Deutsch'), qr{https://biercomics\.de"},
        'Should not link to self');
}
