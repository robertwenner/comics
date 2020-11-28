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
    MockComic::fake_file("comic-page.templ",
        '[% comic.meta_data.title.$Language %]');
}


sub make_comic {
    my ($title, $lang, $published_when, $published_where) = @_;
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED_WHERE => ($published_where || "web"));
    return $comic;
}


sub creates_dir : Tests {
    Comic::export_index({
        $MockComic::ENGLISH => 'comic-page.templ',
        $MockComic::DEUTSCH => 'comic-page.templ',
        $MockComic::ESPAÑOL => 'comic-page.templ',
    });
    MockComic::assert_made_dirs('generated/web/deutsch', 'generated/web/english', 'generated/web/español');
}


sub no_comics_doesnt_die : Tests {
    eval {
        Comic::export_index({$MockComic::ENGLISH => 'comic-page.templ'});
    };
    is('', $@);
}


sub same_comic_current_for_all_languages : Tests {
    MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Beer',
            $MockComic::DEUTSCH => 'Bier',
        },
        $MockComic::PUBLISHED_WHEN => '2020-01-01',
        $MockComic::PUBLISHED_WHERE => "web");
    Comic::export_index({
        $MockComic::ENGLISH => 'comic-page.templ',
        $MockComic::DEUTSCH => 'comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/index.html', 'Bier');
    MockComic::assert_wrote_file('generated/web/english/index.html', 'Beer');
}


sub different_comic_current_per_language : Tests {
    my $en = make_comic('Beer', $MockComic::ENGLISH, '2020-01-01');
    my $de = make_comic('Bier', $MockComic::DEUTSCH, '2020-01-01');
    Comic::export_index({
        $MockComic::ENGLISH => 'comic-page.templ',
        $MockComic::DEUTSCH => 'comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/deutsch/index.html', 'Bier');
    MockComic::assert_wrote_file('generated/web/english/index.html', 'Beer');
}


sub ignores_comics_not_published_on_my_page : Tests {
    make_comic('Use this', $MockComic::ENGLISH, '2020-01-01', 'web');
    make_comic('Ignore this', $MockComic::ENGLISH, '2020-02-01', 'elsewhere');
    Comic::export_index({$MockComic::ENGLISH => 'comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/english/index.html', 'Use this');
}


sub ignores_unpublished_comic : Tests {
    make_comic('Unpublished', $MockComic::ENGLISH);
    make_comic('Published', $MockComic::ENGLISH, '2020-01-01');
    Comic::export_index({$MockComic::ENGLISH => 'comic-page.templ'});
    MockComic::assert_wrote_file('generated/web/english/index.html', 'Published');
}
