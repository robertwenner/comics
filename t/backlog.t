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
[% FOREACH c IN comics %]
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
TEMPL
    MockComic::fake_file("web/deutsch/comic-page.templ", "...");
}


sub make_comic {
    my ($title, $published, $lang) = @_;
    return MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED => $published);
}


sub no_comics : Tests {
    Comic::export_archive('backlog.templ', %languages);
    MockComic::assert_wrote_file('generated/backlog.html', qr{No comics in backlog}m);
}


sub future_date : Tests {
    make_comic('eins', "3016-01-01", 'Deutsch');
    Comic::export_all_html();
    Comic::export_archive('backlog.templ', %languages);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li>some_comic.svg\s+3016-01-01\s*<ul>}mx);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/eins.html">eins</a></li>}mx);
}


sub no_date : Tests {
    make_comic('eins', '', 'Deutsch');
    Comic::export_all_html();
    Comic::export_archive('backlog.templ', %languages);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li>some_comic.svg\s*<ul>}mx);
    MockComic::assert_wrote_file('generated/backlog.html',
        qr{<li><a\shref="backlog/eins.html">eins</a></li>}mx);
}


sub two_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED => '',
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
    my $comic = make_comic('Beer flavored', '4001-01-01', 'Deutsch');
    no warnings qw/redefine/;
    local *Comic::_slurp = sub {
        return '[% IF backlog %][% transcript %][% END %]';
    };
    return $comic->_do_export_html('Deutsch');
    is(write_templ_de($comic), '');
    # Would have fail if the backlog variable was not set.
}
