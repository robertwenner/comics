use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


my %archives;


sub set_up : Test(setup) {
    MockComic::set_up();
    %archives = ("Deutsch" => "web/deutsch/archiv.templ");
    MockComic::fake_file("web/deutsch/archiv.templ", <<'TEMPL');
[% FOREACH c IN comics %]
[% NEXT IF notFor(c, 'Deutsch') %]
<li><a href="[% c.href.Deutsch %]">[% c.meta_data.title.Deutsch %]</a></li>
[% END %]
[% modified %]
TEMPL
    MockComic::fake_file("web/deutsch/comic-page.templ", "...");
}


sub make_comic {
    my ($title, $published, $lang) = @_;
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED => $published);
    $comic->{'prev'}{$lang} = "prev.html";
    $comic->{'first'}{$lang} = "first.html";
    return $comic;
}


sub one_comic : Tests {
    my $comic = make_comic('Bier', '2016-01-01', 'Deutsch');
    Comic::export_archive('backlog.templ', %archives);
    MockComic::assert_wrote_file('generated/deutsch/web/archiv.html',
        qr{<li><a href="comics/bier.html">Bier</a></li>}m);
}


sub some_comics : Tests {
    make_comic("eins", "2016-01-01", 'Deutsch');
    make_comic("zwei", "2016-01-02", 'Deutsch');
    make_comic("drei", "2016-01-03", 'Deutsch');
    Comic::export_archive('backlog.templ', %archives);
    MockComic::assert_wrote_file('generated/deutsch/web/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        <li><a\shref="comics/drei.html">drei</a></li>\s+
    }mx);
}


sub ignores_if_not_that_language : Tests {
    make_comic("eins", "2016-01-01", 'Deutsch');
    make_comic("two", "2016-01-02", 'English');
    make_comic("drei", "2016-01-03", 'Deutsch');
    Comic::export_archive('backlog.templ', %archives);
    MockComic::assert_wrote_file('generated/deutsch/web/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/drei.html">drei</a></li>\s+
        }mx);
    MockComic::assert_wrote_file('generated/deutsch/web/archiv.html', qr{(?!two)}mx);
}


sub ignores_unpublished : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 5, day => 1));
    make_comic('eins', "2016-01-01", 'Deutsch');
    make_comic('zwei', "2016-05-06", 'Deutsch');
    make_comic('drei', "2016-06-01", 'Deutsch');
    Comic::export_archive('backlog.templ', %archives);
    MockComic::assert_wrote_file('generated/deutsch/web/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        }mx);
}


sub no_comics : Tests {
    Comic::export_archive('backlog.templ', %archives);
    MockComic::assert_wrote_file('generated/deutsch/web/archiv.html', qr{No comics in archive}m);
}


sub index_html : Tests {
    MockComic::fake_file("web/deutsch/comic-page.templ",
        '<li><a href="[% first %]" title="zum ersten Biercomic">&lt;&lt; Erstes</a></li>');
    my $c = make_comic('zwei', '2016-01-02', 'Deutsch');
    $c->{'first'}{'Deutsch'} = 'eins.html';
    $c->{'prev'}{'Deutsch'} = 'eins.html';
    $c->{isLatestPublished} = 1;
    my $wrote = $c->_do_export_html('Deutsch');
    like($wrote, qr{href="comics/eins.html"}m);
}


__END__
sub last_modified_from_archive_language : Test {
    make_comic('eins', "2016-01-01", 'Deutsch');
    make_comic('zwei', "2016-01-02", 'Deutsch');
    make_comic('drei', "2016-01-03", 'English');
    Comic::export_archive('backlog.templ', %archives);
    MockComic::assert_wrote_file('generated/deutsch/web/archiv.html', qr{2016-01-02}m);
}
