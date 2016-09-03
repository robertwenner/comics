use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


my %languages;


sub set_up : Test(setup) {
    %languages = (
        $MockComic::DEUTSCH => 'archiv.html',
        $MockComic::ENGLISH => 'archive.html',
    );
    MockComic::set_up();
    MockComic::fake_file("backlog.templ", <<'TEMPL');
<h1>Backlog</h1>
[% FOREACH c IN comics %]
[% IF c.meta_data.published.where == 'web' %]
    <li>[% c.file %] [% c.meta_data.published.when %]
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

<h1>Published elsewhere</h1>
[% FOREACH c IN comics %]
[% IF c.meta_data.published.where != 'web' %]
    <li>[% c.file %] [% c.meta_data.published.when %]
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
TEMPL
    MockComic::fake_file("web/deutsch/comic-page.templ", "...");
}


sub make_comic {
    my ($title, $lang, $published_when, $published_where) = @_;
    return MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED_WHEN => $published_when,
        $MockComic::PUBLISHED_WHERE => ($published_where || "web"));
}


sub no_comics : Tests {
    Comic::export_archive('backlog.templ', %languages);
    MockComic::assert_wrote_file('generated/backlog.html', qr{No comics in backlog}m);
}


sub future_date : Tests {
    make_comic('eins', 'Deutsch', '3016-01-01');
    Comic::export_all_html();
    Comic::export_archive('backlog.templ', %languages);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li>some_comic.svg\s+3016-01-01\s*<ul>}mx);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/eins.html">eins</a></li>}mx);
}


sub no_date : Tests {
    make_comic('eins', 'Deutsch', '');
    Comic::export_all_html();
    Comic::export_archive('backlog.templ', %languages);
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
    Comic::export_all_html();
    Comic::export_archive('backlog.templ', %languages);
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
    Comic::export_all_html();
    Comic::export_archive('backlog.templ', %languages);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/magazined\.html">Magazined!</a></li>});
}


sub comic_not_published_on_my_page_goes_after_regular_backlog : Tests {
    my $backlog = make_comic('Coming up', 'English', '2016-10-01', 'web');
    my $elsewhere = make_comic('Elsewhere', 'English', '2016-09-01', 'magazine');
    Comic::export_all_html();
    Comic::export_archive('backlog.templ', %languages);
    MockComic::assert_wrote_file('generated/backlog.html', qr{
        <li><a\shref="backlog/coming-up\.html">Coming\sup</a></li>
        .*Published\selsewhere.*
        <li><a\shref="backlog/elsewhere\.html">Elsewhere</a></li>
    }xsm);
}
