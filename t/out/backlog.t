use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

use Comic::Out::Backlog;


__PACKAGE__->runtests() unless caller;


my $backlog;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file("backlog.templ", <<'TEMPL');
<h1>Backlog</h1>
[% FOREACH publisher IN publishers %][% END %]
[% FOREACH c IN comics %][% END %]
[% FOREACH l IN languages %][% END %]
[% FOREACH t IN tags %][% END %]
[% FOREACH t IN tagOrder %][% END %]
[% FOREACH s IN series %][% END %]
[% FOREACH s IN seriesOrder %][% END %]
[% FOREACH w IN who %][% END %]
[% FOREACH w IN whoOrder %][% END %]
TEMPL

    $backlog = Comic::Out::Backlog->new({
        'Backlog' => {
            'template' => 'backlog.templ',
            'outfile' => 'generated/backlog.html',
        },
    });
}


sub make_comic {
    my ($title, $lang, $published_when, $published_where) = @_;
    return MockComic::make_comic(
        $MockComic::TITLE => { $lang => $title },
        $MockComic::PUBLISHED_WHEN => $published_when,
        $MockComic::PUBLISHED_WHERE => ($published_where || "web"));
}


sub make_comic_with_tag {
    my ($tag) = @_;
    return MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Bier trinken' },
        $MockComic::TAGS => { $MockComic::DEUTSCH => [$tag]},
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );
}


sub make_comic_with_people {
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


sub constructor_arguments : Tests {
    eval {
        $backlog = Comic::Out::Backlog->new();
    };
    like($@, qr{configuration});

    eval {
        $backlog = Comic::Out::Backlog->new({
            'Backlog' => {
            },
        });
    };
    like($@, qr{\bBacklog\.template\b});

    eval {
        $backlog = Comic::Out::Backlog->new({
            'Backlog' => {
                'outfile' => '...',
            },
        });
    };
    like($@, qr{\btemplate\b});

    eval {
        $backlog = Comic::Out::Backlog->new({
            'Backlog' => {
                'template' => '...',
            },
        });
    };
    like($@, qr{\boutfile\b});
}


sub generate_all : Tests {
    MockComic::fake_file("backlog.templ", '<h1>Backlog</h1>');
    my $comic = make_comic('1', 'English', '3016-01-01', 'cbb');
    $backlog->generate_all($comic);
    MockComic::assert_wrote_file('generated/backlog.html', qr{<h1>Backlog</h1>}m);
}


sub generate_all_no_comics_processes_template : Tests {
    MockComic::fake_file("backlog.templ", '<h1>Backlog</h1>');
    $backlog->generate_all();
    MockComic::assert_wrote_file('generated/backlog.html', qr{<h1>Backlog</h1>}m);
}


sub publishers_no_top_location_no_backlog : Tests {
    is_deeply($backlog->_publishers(), []);
}


sub publishers_top_location_no_backlog : Tests {
    $backlog = Comic::Out::Backlog->new({
        'Backlog' => {
            'template' => 'backlog.templ',
            'outfile' => 'generated/backlog.html',
            'toplocation' => 'web',
        },
    });
    is_deeply($backlog->_publishers(), ['web']);
}


sub publishers_order_top_location : Tests {
    my @comics = (
        make_comic('1', 'English', '3016-01-01', 'cbb'),
        make_comic('2', 'Deutsch', '3016-01-01', 'braumagazin.de'),
        make_comic('3', 'English', '3016-01-01', 'austin beer guide'),
        make_comic('4', 'English', '3016-01-01', 'web'),
        make_comic('5', 'English', '3016-01-01', 'Web'),
    );
    $backlog = Comic::Out::Backlog->new({
        'Backlog' => {
            'template' => 'backlog.templ',
            'outfile' => 'generated/backlog.html',
            'toplocation' => 'web',
        },
    });
    is_deeply($backlog->_publishers(@comics),
       ['web', 'austin beer guide', 'braumagazin.de', 'cbb']);
}


sub publishers_order_no_top_location : Tests {
    my @comics = (
        make_comic('1', 'English', '3016-01-01', 'cbb'),
        make_comic('2', 'English', '3016-01-01', 'web'),
        make_comic('3', 'Deutsch', '3016-01-01', 'braumagazin.de'),
        make_comic('4', 'English', '3016-01-01', 'austin beer guide'),
        make_comic('5', 'English', '3016-01-01', 'Web'),
        make_comic('6', 'English', '3016-01-01', 'web'),
    );
    is_deeply($backlog->_publishers(@comics),
       ['austin beer guide', 'braumagazin.de', 'cbb', 'web']);
}


sub populates_fields_empty_backlog : Tests {
    my %vars = $backlog->_populate_vars();

    is_deeply($vars{publishers}, []);
    is_deeply($vars{languages}, []);
    is_deeply($vars{comics}, []);
    is_deeply($vars{tagsOrder}, []);
    is_deeply($vars{tags}, {});
    is_deeply($vars{whoOrder}, []);
    is_deeply($vars{who}, {});
    is_deeply($vars{seriesOrder}, []);
    is_deeply($vars{series}, {});
}


sub populates_fields_one_comic_in_backlog : Tests {
    my $comic = make_comic('eins', 'Deutsch', '3016-01-01');

    my %vars = $backlog->_populate_vars($comic);

    is_deeply($vars{publishers}, ['web']);
    is_deeply($vars{languages}, ['Deutsch']);
    is_deeply($vars{comics}, [$comic]);
    is_deeply($vars{tagsOrder}, ['Bier (Deutsch)', 'Craft (Deutsch)']);
    is_deeply($vars{tags}, {'Bier (Deutsch)' => 1, 'Craft (Deutsch)' => 1});
    is_deeply($vars{whoOrder}, []);
    is_deeply($vars{who}, {});
    is_deeply($vars{seriesOrder}, []);
    is_deeply($vars{series}, {});
}


sub two_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
            $MockComic::DEUTSCH => "Bier!",
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ["etag"],
            $MockComic::DEUTSCH => ["dtag"],
        },
    );

    my %vars = $backlog->_populate_vars($comic);

    is_deeply($vars{publishers}, ['web']);
    is_deeply($vars{languages}, ['Deutsch', 'English']);
    is_deeply($vars{comics}, [$comic]);
    is_deeply($vars{tagsOrder}, ['dtag (Deutsch)', 'etag (English)']);
    is_deeply($vars{tags}, {'dtag (Deutsch)' => 1, 'etag (English)' => 1});
}


sub comic_not_published_on_my_page : Tests {
    my $comic = make_comic('Magazined!', 'Deutsch', '2016-01-01', 'some beer magazine');

    my %vars = $backlog->_populate_vars($comic);

    is_deeply($vars{publishers}, ['some beer magazine']);
    is_deeply($vars{languages}, ['Deutsch']);
    is_deeply($vars{comics}, [$comic]);
}


sub includes_language_in_series : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::DEUTSCH => 'Bier trinken' },
        $MockComic::SERIES => { $MockComic::DEUTSCH => 'Bym' },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );

    my %vars = $backlog->_populate_vars($comic);

    is_deeply($vars{series}, {'Bym (Deutsch)' => 1});
    is_deeply($vars{seriesOrder}, ['Bym (Deutsch)']);
}


sub includes_lanuage_in_series_some_language_has_no_series: Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken',
            $MockComic::ENGLISH => 'Drink beer',
        },
        $MockComic::SERIES => { $MockComic::DEUTSCH => 'Bym' },
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
    );

    my %vars = $backlog->_populate_vars($comic);

    is_deeply($vars{series}, {'Bym (Deutsch)' => 1});
    is_deeply($vars{seriesOrder}, ['Bym (Deutsch)']);
}


sub tags : Tests {
    my @comics = (
        make_comic_with_tag('Bym'),
        make_comic_with_tag('Bym'),
        make_comic_with_tag('YetOther'),
        make_comic_with_tag('Other'),
        make_comic_with_tag('Bym'),
        make_comic_with_tag('Other'),
        make_comic_with_tag('AndThenSome'),
        make_comic_with_tag('YetOther'),
    );

    my %vars = $backlog->_populate_vars(@comics);

    is_deeply($vars{tags}, {'Bym (Deutsch)' => 3, 'Other (Deutsch)' => 2, 'YetOther (Deutsch)' => 2, 'AndThenSome (Deutsch)' => 1});
    is_deeply($vars{tagsOrder}, ['Bym (Deutsch)', 'Other (Deutsch)', 'YetOther (Deutsch)', 'AndThenSome (Deutsch)']);
}


sub tags_case_are_sensitive : Tests {
    my @comics = (
        make_comic_with_tag('Bym'),
        make_comic_with_tag('bym'),
        make_comic_with_tag('ale'),
    );

    my %vars = $backlog->_populate_vars(@comics);

    is_deeply($vars{tags}, {'ale (Deutsch)' => 1, 'Bym (Deutsch)' => 1, 'bym (Deutsch)' => 1});
    is_deeply($vars{tagsOrder}, ['ale (Deutsch)', 'Bym (Deutsch)', 'bym (Deutsch)']);
}


sub who : Tests {
    my @comics = (
        make_comic_with_people('Paul', 'Max'),
        make_comic_with_people('Paul', 'Max'),
        make_comic_with_people('Paul'),
        make_comic_with_people('Mike', 'Robert'),
    );

    my %vars = $backlog->_populate_vars(@comics);

    is_deeply($vars{who}, {'Paul (Deutsch)' => 3, 'Max (Deutsch)' => 2, 'Mike (Deutsch)' => 1, 'Robert (Deutsch)' => 1});
    is_deeply($vars{whoOrder}, ['Paul (Deutsch)', 'Max (Deutsch)', 'Mike (Deutsch)', 'Robert (Deutsch)']);
}


sub who_case : Tests {
    my @comics = (
        make_comic_with_people('Paul'),
        make_comic_with_people('paul'),
        make_comic_with_people('max'),
    );

    my %vars = $backlog->_populate_vars(@comics);

    is_deeply($vars{who}, {'max (Deutsch)' => 1, 'Paul (Deutsch)' => 1, 'paul (Deutsch)' => 1});
    is_deeply($vars{whoOrder}, ['max (Deutsch)', 'Paul (Deutsch)', 'paul (Deutsch)']);
}


sub series : Tests {
    my @comics = (
        make_comic_with_series('Buckimude'),
        make_comic_with_series('Buckimude'),
        make_comic_with_series('Philosophie'),
    );

    my %vars = $backlog->_populate_vars(@comics);

    is_deeply($vars{series}, {'Buckimude (Deutsch)' => 2, 'Philosophie (Deutsch)' => 1});
    is_deeply($vars{seriesOrder}, ['Buckimude (Deutsch)', 'Philosophie (Deutsch)']);
}


sub series_case : Tests {
    my @comics = (
        make_comic_with_series('AAA'),
        make_comic_with_series('bbb'),
        make_comic_with_series('CCC'),
        make_comic_with_series('ddd'),
    );

    my %vars = $backlog->_populate_vars(@comics);

    is_deeply($vars{series}, {'AAA (Deutsch)' => 1, 'bbb (Deutsch)' => 1, 'CCC (Deutsch)' => 1, 'ddd (Deutsch)' => 1});
    is_deeply($vars{seriesOrder}, ['AAA (Deutsch)', 'bbb (Deutsch)', 'CCC (Deutsch)', 'ddd (Deutsch)']);
}


sub empty_series_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"series": {}',
        $MockComic::PUBLISHED_WHEN => '3000-01-01',
    );

    my %vars = $backlog->_populate_vars($comic);

    is_deeply($vars{series}, {});
    is_deeply($vars{seriesOrder}, []);
}
