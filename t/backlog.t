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
                [% FOREACH w IN c.warnings %]
                    <span style="color: red">[% w %]</span>
                [% END %]
                <ul>
                    [% FOREACH l IN languages %]
                    [% DEFAULT c.meta_data.title.$l = 0 %]
                        [% IF c.meta_data.title.$l %]
                        <li><a href="backlog/[% c.htmlFile.$l %]">[% c.meta_data.title.$l %]</a>
                            [% IF c.meta_data.defined('series') %] ([% c.meta_data.series.$l %])[% END %]
                        </li>
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


sub make_tagged_comic {
    my ($tag) = @_;
    return MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Bier trinken' },
        $MockComic::TAGS => { $MockComic::DEUTSCH => [$tag]},
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
}


sub make_comic_with {
    return MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Bier trinken' },
        $MockComic::WHO => { $MockComic::DEUTSCH => [@_] },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
}


sub make_comic_with_series {
    my ($series) = @_;
    return MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Bier trinken' },
        $MockComic::SERIES => { $MockComic::DEUTSCH => $series },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
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
        qr{<li><a\shref="backlog/deutsch/eins.html">eins</a>\s*</li>}mx);
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
        qr{<li><a\shref="backlog/deutsch/eins.html">eins</a>\s*</li>}mx);
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
        qr{<li><a\shref="backlog/deutsch/bier.html">Bier!</a>\s*</li>\s*
           <li><a\shref="backlog/english/beer.html">Beer!</a>\s*</li>}mx);
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
        qr{<li><a\shref="backlog/deutsch/magazined\.html">Magazined!</a>\s*</li>});
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
        <li><a\shref="backlog/english/coming-up\.html">Coming\sup</a>\s*</li>
        .*magazine.*
        <li><a\shref="backlog/english/elsewhere\.html">Elsewhere</a>\s*</li>
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
        <li><a\shref="backlog/english/beer-guide\.html">Beer\sGuide</a>\s*</li>.*
        <h2>braumagazin\.de</h2>.*
        <li><a\shref="backlog/deutsch/brau-okt\.html">Brau\sOkt</a>\s*</li>.*
        <li><a\shref="backlog/deutsch/brau-dez\.html">Brau\sDez</a>\s*</li>
    }xsm);
}


sub publisher_order : Tests {
    make_comic('1', 'English', '3016-01-01', 'Craft Beer &amp; Brewing');
    make_comic('2', 'Deutsch', '3016-01-01', 'braumagazin.de');
    make_comic('3', 'English', '3016-01-01', 'Austin Beer Guide');
    make_comic('4', 'English', '3016-01-01', 'web');
    is_deeply(Comic::_publishers(),
       ['web', 'Austin Beer Guide', 'braumagazin.de', 'Craft Beer & Brewing']);
}


sub includes_series : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Bier trinken' },
        $MockComic::SERIES => { $MockComic::DEUTSCH => 'Bym' },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', qr{
        <li><a\shref="backlog/deutsch/bier-trinken\.html">Bier\strinken</a>\s+\(Bym\)\s+</li>
    }xsm);
}


sub includes_dont_publish_warning : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Bier trinken' },
        $MockComic::TEXTS => { $MockComic::DEUTSCH => ['a', 'b', 'DONT_PUBLISH', 'c']},
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
    $comic->_check_dont_publish();
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', qr{
        <li>some_comic\.svg\s+.+DONT_PUBLISH.+<ul>}xsm);
}


sub tags : Tests {
    MockComic::fake_file("backlog.templ", <<'TEMPL');
       [% FOREACH t IN tagsOrder %]
            [% t %]=[% tags.$t %]
       [% END %]
TEMPL
    make_tagged_comic('Bym');
    make_tagged_comic('Bym');
    make_tagged_comic('YetOther');
    make_tagged_comic('Other');
    make_tagged_comic('Bym');
    make_tagged_comic('Other');
    make_tagged_comic('AndThenSome');
    make_tagged_comic('YetOther');
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', 
        qr{^\s*Bym\s\(Deutsch\)=3\s*Other\s\(Deutsch\)=2\s*
           YetOther\s\(Deutsch\)=2\s*AndThenSome\s\(Deutsch\)=1\s*$}xsm);
}


sub tags_case : Tests {
    MockComic::fake_file("backlog.templ", <<'TEMPL');
       [% FOREACH t IN tagsOrder %]
            [% t %]=[% tags.$t %]
       [% END %]
TEMPL
    make_tagged_comic('Bym');
    make_tagged_comic('bym');
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{^\s*Bym\s\(Deutsch\)=1\s*bym\s\(Deutsch\)=1\s*$}xsm);
}


sub who : Tests {
    MockComic::fake_file("backlog.templ", <<'TEMPL');
       [% FOREACH w IN whoOrder %]
            [% w %]=[% who.$w %]
       [% END %]
TEMPL
    make_comic_with('Paul', 'Max');
    make_comic_with('Paul', 'Max');
    make_comic_with('Paul');
    make_comic_with('Mike', 'Robert');
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', 
        qr{^\s*Paul\s\(Deutsch\)=3\s*Max\s\(Deutsch\)=2\s*
          Mike\s\(Deutsch\)=1\s*Robert\s\(Deutsch\)=1\s*$}xsm);
}


sub who_case : Tests {
    MockComic::fake_file("backlog.templ", <<'TEMPL');
       [% FOREACH w IN whoOrder %]
            [% w %]=[% who.$w %]
       [% END %]
TEMPL
    make_comic_with('Paul');
    make_comic_with('paul');
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{^\s*Paul\s\(Deutsch\)=1\s*paul\s\(Deutsch\)=1\s*}xsm);
}


sub series : Tests {
    MockComic::fake_file("backlog.templ", <<'TEMPL');
       [% FOREACH s IN seriesOrder %]
            [% s %]=[% series.$s %]
       [% END %]
TEMPL
    make_comic_with_series('Buckimude');
    make_comic_with_series('Buckimude');
    make_comic_with_series('Philosophie');
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/backlog.html', 
        qr{^\s*Buckimude\s\(Deutsch\)=2\s*Philosophie\s\(Deutsch\)=1\s*$}xsm);
}
