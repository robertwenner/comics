use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file("backlog.templ", <<'TEMPL');
<h1>Backlog</h1>
[% FOREACH publisher IN publishers %]
    <h2>[% publisher %]</h2>

    [% FOREACH c IN comics %]
        [% IF c.meta_data.published.where == publisher %]
            <li>[% c.srcFile %] [% c.meta_data.published.when %]
                <ul>
                    [% FOREACH l IN languages %]
                    [% DEFAULT c.meta_data.title.$l = 0 %]
                        [% IF c.meta_data.title.$l %]
                        <li><a href="backlog/[% c.htmlFile.$l %]">[% c.meta_data.title.$l %]</a></li>
                        [% END %]
                    [% END %]
                </ul>
            </li>
        [% END %]
    [% END %]
[% END %]
TEMPL
    MockComic::fake_file("templates/deutsch/comic-page.templ", "...");
    MockComic::fake_file("templates/english/comic-page.templ", "...");
    MockComic::fake_file("templates/deutsch/sitemap-xml.templ", "...");
    MockComic::fake_file("templates/english/sitemap-xml.templ", "...");
    MockComic::fake_file("templates/sitemap.templ", "...");
}


sub make_comic {
    my ($title, $lang, $published_when, $published_where) = @_;
    return MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED_WHEN => $published_when,
        $MockComic::PUBLISHED_WHERE => ($published_where || "web"));
}


sub no_comics : Tests {
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', qr{No comics in backlog}m);
}


sub future_date : Tests {
    make_comic('eins', 'Deutsch', '3016-01-01');
    Comic::export_all_html(
        {'Deutsch' => 'templates/deutsch/comic-page.templ'},
        {'Deutsch' => 'templates/sitemap.templ'}, 
        {'Deutsch' => 'generated/sitemap.html'});
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li>some_comic.svg\s+3016-01-01\s*<ul>}mx);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/eins.html">eins</a></li>}mx);
}


sub no_date : Tests {
    make_comic('eins', 'Deutsch', '');
    Comic::export_all_html(
        {'Deutsch' => 'templates/deutsch/comic-page.templ'},
        {'Deutsch' => 'templates/sitemap.templ'}, 
        {'Deutsch' => 'generated/sitemap.html'});
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li>some_comic.svg\s*<ul>}mx);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/eins.html">eins</a></li>}mx);
}


sub two_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
            $MockComic::DEUTSCH => "Bier!"});
    Comic::export_all_html(
        {'Deutsch' => 'templates/deutsch/comic-page.templ',
         'English' => 'templates/english/comic-page.templ'},
        {'Deutsch' => 'templates/sitemap.templ',
         'English' => 'templates/sitemap.templ'},
        {'Deutsch' => 'generated/sitemap.html',
         'English' => 'generated/sitemap.html'});
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ',
         'English' => 'templates/english/archive.templ'},
        {'Deutsch' => 'archiv.html',
         'English' => 'archive.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ',
         'English' => 'templates/english/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/bier.html">Bier!</a></li>\s*
           <li><a\shref="backlog/beer.html">Beer!</a></li>}mx);
}


sub transcript : Test {
    my $comic = make_comic('Beer flavored', 'Deutsch', '4001-01-01');
    no warnings qw/redefine/;
    local *Comic::_slurp = sub {
        return '[% IF backlog %][% transcriptHtml %][% END %]';
    };
    $comic->_do_export_html('Deutsch');
    # Would have fail if the backlog variable was not set.
}


sub comic_not_published_on_my_page : Tests {
    my $comic = make_comic('Magazined!', 'Deutsch', '2016-01-01', 'some beer magazine');
    Comic::export_all_html(
        {'Deutsch' => 'templates/deutsch/comic-page.templ'},
        {'Deutsch' => 'templates/sitemap.templ'}, 
        {'Deutsch' => 'generated/sitemap.html'});
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/magazined\.html">Magazined!</a></li>});
}


sub comic_not_published_on_my_page_goes_after_regular_backlog : Tests {
    make_comic('Coming up', 'English', '3016-10-01', 'web');
    make_comic('Elsewhere', 'English', '3016-09-01', 'magazine');
    Comic::export_all_html(
        {'English' => 'templates/english/comic-page.templ'},
        {'English' => 'templates/sitemap.templ'}, 
        {'English' => 'generated/sitemap.html'});
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'English' => 'templates/english/archive.templ'},
        {'English' => 'archive.html'},
        {'English' => 'templates/english/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', qr{
        .*Backlog.*
        .*web.*
        <li><a\shref="backlog/coming-up\.html">Coming\sup</a></li>
        .*magazine.*
        <li><a\shref="backlog/elsewhere\.html">Elsewhere</a></li>
    }xsm);
}


sub comics_not_published_grouped_by_publisher : Tests {
    make_comic('Brau Okt', 'Deutsch', '2015-10-01', 'braumagazin.de');
    make_comic('Beer Guide', 'English', '2015-11-01', 'Austin Beer Guide');
    make_comic('Brau Dez', 'Deutsch', '2015-12-01', 'braumagazin.de');
    Comic::export_all_html(
        {'Deutsch' => 'templates/deutsch/comic-page.templ',
         'English' => 'templates/english/comic-page.templ'},
        {'Deutsch' => 'templates/sitemap.templ',
         'English' => 'templates/sitemap.templ'},
        {'Deutsch' => 'generated/sitemap.html',
         'English' => 'generated/sitemap.html'});
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ',
         'English' => 'templates/english/archive.templ'},
        {'Deutsch' => 'archiv.html',
         'English' => 'archive.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ',
         'English' => 'templates/english/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', qr{
        <h2>Austin\sBeer\sGuide</h2>.*
        <li><a\shref="backlog/beer-guide\.html">Beer\sGuide</a></li>.*
        <h2>braumagazin\.de</h2>.*
        <li><a\shref="backlog/brau-okt\.html">Brau\sOkt</a></li>.*
        <li><a\shref="backlog/brau-dez\.html">Brau\sDez</a></li>
    }xsm);
}


sub publisher_order : Tests {
    make_comic('1', 'English', '3016-01-01', 'Craft Beer &amp; Brewing');
    make_comic('2', 'Deutsch', '3016-01-01', 'braumagazin.de');
    make_comic('3', 'English', '3016-01-01', 'Austin Beer Guide');
    make_comic('4', 'English', '3016-01-01', 'web');
    is_deeply(Comic::_publishers(),
       ['web', 'Austin Beer Guide', 'braumagazin.de', 'Craft Beer &amp; Brewing']);
}
