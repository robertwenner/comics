use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

use Comic::Out::HtmlComicPage;


__PACKAGE__->runtests() unless caller;


my $hcp;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file("comic-page.templ",'');
    $hcp = Comic::Out::HtmlComicPage->new({
        'Comic::Out::HtmlComicPage' => {
            'outdir' => 'generated',
            'Templates' => {
                $MockComic::ENGLISH => 'comic-page.templ',
                $MockComic::DEUTSCH => 'comic-page.templ',
                "$MockComic::ESPAÑOL" => 'comic-page.templ',
            },
            'Domains' => {
                $MockComic::ENGLISH => 'beercomics.com',
                $MockComic::DEUTSCH => 'biercomics.de',
                "$MockComic::ESPAÑOL" => 'cervezacomics.es',
            },
        },
    });
}


sub make_comic {
    my ($title, $lang, $published_when, $published_where) = @_;
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED_WHERE => ($published_where || "web"));
    return $comic;
}


sub creates_dirs_only_for_languages_with_latest_comics : Tests {
    my $comic = MockComic::make_comic();
    $hcp->export_index($comic);
    MockComic::assert_made_dirs(
        'generated/tmp/meta/',
        'generated/web/deutsch/comics',
        'generated/web/english/comics',
    );
}


sub no_comics_doesnt_die : Tests {
    eval {
        $hcp->export_index();
    };
    is('', $@);
}


sub latest_published_same_comic_for_all_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Beer',
            $MockComic::DEUTSCH => 'Bier',
        },
        $MockComic::PUBLISHED_WHEN => '2020-01-01',
        $MockComic::PUBLISHED_WHERE => "web");

    my %latest = $hcp->_find_latest_published($comic);
    is_deeply(\%latest, {'Deutsch' => $comic, 'English' => $comic});
    ok($comic->{isLatestPublished}, 'Comic should be marked as latest published');
}


sub latest_published_different_comic_current_per_language : Tests {
    my $en = make_comic('Beer', $MockComic::ENGLISH, '2020-01-01');
    my $de = make_comic('Bier', $MockComic::DEUTSCH, '2020-01-01');

    my %latest = $hcp->_find_latest_published($en, $de);
    is_deeply(\%latest, {'Deutsch' => $de, 'English' => $en});
    ok($de->{isLatestPublished}, 'German comic should be marked as latest published');
    ok($en->{isLatestPublished}, 'English comic should be marked as latest published');
}


sub latest_published_ignores_comics_not_published_on_the_web : Tests {
    my $use = make_comic('Use this', $MockComic::ENGLISH, '2020-01-01', 'web');
    my $ignore = make_comic('Ignore this', $MockComic::ENGLISH, '2020-02-01', 'elsewhere');

    my %latest = $hcp->_find_latest_published($use, $ignore);
    is_deeply(\%latest, {'English' => $use});
    ok($use->{isLatestPublished}, 'Published comic should be latest');
    is($ignore->{isLatestPublished}, undef, 'Comic published elsewhere should not be marked latest');
}


sub latest_published_ignores_unpublished_comic : Tests {
    my $unpublished = make_comic('Unpublished', $MockComic::ENGLISH);
    my $published = make_comic('Published', $MockComic::ENGLISH, '2020-01-01');

    my %latest = $hcp->_find_latest_published($unpublished, $published);
    is_deeply(\%latest, {'English' => $published});
    ok($published->{isLatestPublished}, 'Published comic should be latest');
    is($unpublished->{isLatestPublished}, undef, 'Unpublished comic should not be marked latest');
}
