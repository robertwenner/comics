use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

use Comic::Out::HtmlArchivePage;


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
    $comic->{'href'}{$lang} = "comics/" . lc($title) . ".html";
    $comic->{'url'}{$lang} = "https://...";
    return $comic;
}


sub generate {
    my @comics = @_;
    my $archive = Comic::Out::HtmlArchivePage->new(
        'template' => {
            'Deutsch' => 'templates/deutsch/archiv.templ',
        },
        'outfile' => {
            'Deutsch' => 'generated/web/deutsch/archiv.html',
        },
    );
    $archive->generate_all(@comics);
}


sub ctor_complains_about_missing_config : Tests {
    eval {
        Comic::Out::HtmlArchivePage->new();
    };
    like($@, qr{HtmlArchivePage}, 'should mention module');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'template' => {
                'English' => '...',
            },
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage\.outfile}, 'should say what is missing');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'outfile' => {
                'English' => '...',
            },
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage\.template}, 'should say what is missing');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'template' => {
                'English' => '...',
            },
            'outfile' => '...',
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage\.outfile}, 'should say where it is wrong');
    like($@, qr{\bmust be hash\b}, 'should say what is wrong');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'template' => {
            },
            'outfile' => {
                'English' => '...',
            },
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage}, 'should mention module');
    like($@, qr{\btemplate\b}, 'should say where it is missing');
    like($@, qr{\boutfile\b}, 'should say where it has the value');
    like($@, qr{English}, 'should say what language is  missing');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'template' => {
                'Deutsch' => '...',
            },
            'outfile' => {
                'English' => '...',
            }
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage}, 'should mention module');
    like($@, qr{Deutsch}, 'should mention language');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'template' => {
                'Deutsch' => 'templates/deutsch/archiv.templ',
            },
            'outfile' => {},
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage}, 'should mention module');
    like($@, qr{Deutsch}, 'should mention language');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'template' => {
                'Deutsch' => 'templates/deutsch/archiv.templ',
                'English' => 'templates/english/archive.templ',
            },
            'outfile' => {
                'Deutsch' => 'generated/web/deutsch/archiv.templ',
            },
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage}, 'should mention module');
    like($@, qr{English}, 'should mention language');

    eval {
        Comic::Out::HtmlArchivePage->new(
            'template' => {
                'Deutsch' => 'templates/deutsch/archiv.templ',
            },
            'outfile' => {
                'Deutsch' => 'generated/web/deutsch/archiv.html',
                'English' => 'generated/web/english/archive.html',
            },
        );
    };
    like($@, qr{Comic::Out::HtmlArchivePage}, 'should mention module');
    like($@, qr{English}, 'should mention language');
}


sub one_comic : Tests {
    my $comic = make_comic('Bier', 'Deutsch', '2016-01-01');
    generate($comic);
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html',
        qr{<li><a href="comics/bier.html">Bier</a></li>}m);
}


sub some_comics : Tests {
    my @comics = (
        make_comic("zwei", 'Deutsch', "2016-01-02"),
        make_comic("eins", 'Deutsch', "2016-01-01"),
        make_comic("drei", 'Deutsch', "2016-01-03"),
    );
    generate(@comics);
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        <li><a\shref="comics/drei.html">drei</a></li>\s+
    }mx);
}


sub croaks_if_no_template_for_language : Tests {
    my $archive = Comic::Out::HtmlArchivePage->new(
        'template' => {
            'English' => 'archive.templ',
        },
        'outfile' => {
            'English' => 'english/web/archive.templ',
        },
    );
    my $comic = make_comic("beer", 'Deutsch', "2016-01-01");
    eval {
        $archive->generate_all($comic);
    };
    like($@, qr{\btemplate\b}i, 'should say what is mising');
    like($@, qr{\bDeutsch\b}i, 'should mention language');
}


sub croaks_if_no_outfile_for_language : Tests {
    my $archive = Comic::Out::HtmlArchivePage->new(
        'template' => 'archive.templ',
        'outfile' => {},
    );
    my $comic = make_comic("beer", 'English', "2016-01-01");
    eval {
        $archive->generate_all($comic);
    };
    like($@, qr{\boutfile\b}i, 'should say what is mising');
    like($@, qr{\bEnglish\b}i, 'should mention language');
}


sub ignores_unpublished : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 5, day => 1));
    my @comics = (
        make_comic('eins', 'Deutsch', "2016-01-01"), # Fri
        make_comic('zwei', 'Deutsch', "2016-05-01"), # Sun
        make_comic('drei', 'Deutsch', "2016-05-02"), # Mon
    );
    generate(@comics);
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        }mx);
}


sub thursday_gets_next_days_comic : Tests {
    MockComic::fake_now(DateTime->new(year => 2016, month => 8, day => 11)); # Thur
    my @comics = (
        make_comic('eins', 'Deutsch', "2016-08-05"), # Fri
        make_comic('zwei', 'Deutsch', "2016-08-12"), # Fri
    );
    generate(@comics);
    MockComic::assert_wrote_file('generated/web/deutsch/archiv.html', qr{
        <li><a\shref="comics/eins.html">eins</a></li>\s+
        <li><a\shref="comics/zwei.html">zwei</a></li>\s+
        }mx);
}


sub no_comics : Tests {
    generate();
    MockComic::assert_didnt_write_in_file('generated/web/deutsch/archiv.html');
}


sub ignores_comics_not_published_on_my_page : Tests {
    my $comic = make_comic('Magazined!', 'Deutsch', '2016-01-01', 'some beer magazine');
    generate($comic);
    MockComic::assert_didnt_write_in_file('generated/web/deutsch/archiv.html');
}


sub passes_language_to_templatize : Tests {
    my $comic = make_comic("eins", 'Deutsch', "2016-01-01");
    $comic->{modified} = 'right now';

    no warnings qw/redefine/;
    local *Comic::Out::Template::templatize = sub {
        my ($description, $template_file, $language, %vars) = @_;

        is($language, 'Deutsch', 'wrong language');
        is($description, 'archive', 'wrong description');
        is($template_file, 'templates/deutsch/archiv.templ', 'wrong template file');
        is_deeply(\%vars, {
            'comics' => [$comic],
            'modified' => 'right now',
            'notFor' => \&Comic::not_for,
            'root' => '',
        }, 'wrong vars');
    };
    use warnings;

    generate($comic);

    # would have failed in the mocked method
}
