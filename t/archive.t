use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file("templates/deutsch/archiv.templ", <<'TEMPL');
[% FOREACH c IN comics %]
[% NEXT IF notFor(c, 'Deutsch') %]
<li><a href="[% c.href.Deutsch %]">[% c.meta_data.title.Deutsch %]</a></li>
[% END %]
[% modified %]
TEMPL
    MockComic::fake_file("templates/deutsch/comic-page.templ",
        '[% comic.meta_data.title.$Language %]');
}


sub make_comic {
    my ($title, $lang, $published_when, $published_where) = @_;
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED_WHEN => $published_when,
        $MockComic::PUBLISHED_WHERE => ($published_where || "web"));
    $comic->{'prev'}{$lang} = "prev.html";
    $comic->{'first'}{$lang} = "first.html";
    return $comic;
}


sub one_comic : Tests {
    my $comic = make_comic('Bier', 'Deutsch', '2016-01-01');
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'generated/web/deutsch/archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html',
        qr{<li><a href="comics/bier.html">Bier</a></li>}m);
}


sub some_comics : Tests {
    make_comic("eins", 'Deutsch', "2016-01-01");
    make_comic("zwei", 'Deutsch', "2016-01-02");
    make_comic("drei", 'Deutsch', "2016-01-03");
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'generated/web/deutsch/archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        <li><a\shref="comics/drei.html">drei</a></li>\s+
    }mx);
}


sub ignores_if_not_that_language : Tests {
    make_comic("eins", 'Deutsch', "2016-01-01");
    make_comic("two", 'English', "2016-01-02");
    make_comic("drei", 'Deutsch', "2016-01-03");
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'generated/web/deutsch/archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/drei.html">drei</a></li>\s+
        }mx);
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{(?!two)}mx);
}


sub ignores_unpublished : Tests {
    MockComic::fake_file('backlog.templ', '...');
    MockComic::fake_now(DateTime->new(year => 2016, month => 5, day => 1));
    make_comic('eins', 'Deutsch', "2016-01-01"); # Fri
    make_comic('zwei', 'Deutsch', "2016-05-01"); # Sun
    make_comic('drei', 'Deutsch', "2016-05-02"); # Mon
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'generated/web/deutsch/archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        }mx);
}


sub thursday_gets_next_days_comic : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 11)); # Thur
    make_comic('eins', 'Deutsch', "2016-08-05"); # Fri
    make_comic('zwei', 'Deutsch', "2016-08-12"); # Fri
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'generated/web/deutsch/archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        }mx);
}


sub no_comics : Tests {
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'generated/web/deutsch/archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{No comics in archive}m);
}


sub index_html : Tests {
    MockComic::fake_file("templates/deutsch/comic-page.templ",
        '<li><a href="[% indexAdjust %][% comic.first.$Language %]" title="zum ersten Biercomic">&lt;&lt; Erstes</a></li>');
    my $c = make_comic('zwei', 'Deutsch', '2016-01-02');
    $c->{'first'}{'Deutsch'} = 'eins.html';
    $c->{'prev'}{'Deutsch'} = 'eins.html';
    $c->{isLatestPublished} = 1;
    my $wrote = $c->_do_export_html('Deutsch', 'templates/deutsch/comic-page.templ');
    like($wrote, qr{href="comics/eins.html"}m);
}


sub ignores_comics_not_published_on_my_page : Tests {
    my $comic = make_comic('Magazined!', 'Deutsch', '2016-01-01', 'some beer magazine');
    is('Magazined!', $comic->_do_export_html('Deutsch', 'templates/deutsch/comic-page.templ'));
    MockComic::fake_file('backlog.templ', '');
    Comic::export_archive('backlog.templ', 'generated/backlog.html',
        {'Deutsch' => 'templates/deutsch/archiv.templ'},
        {'Deutsch' => 'generated/web/deutsch/archiv.html'},
        {'Deutsch' => 'templates/deutsch/comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{No comics in archive}m);
}


__END__
sub last_modified_from_archive_language : Test {
    make_comic('eins', "2016-01-01", 'Deutsch');
    make_comic('zwei', "2016-01-02", 'Deutsch');
    make_comic('drei', "2016-01-03", 'English');
    Comic::export_archive('backlog.templ', %archives);
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{2016-01-02}m);
}
