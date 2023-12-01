use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Out::Series;

__PACKAGE__->runtests() unless caller;

my @comics;


sub set_up : Test(setup) {
    MockComic::set_up();

    @comics = ();
    foreach my $i (1..3) {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::DEUTSCH => "Bier $i",
                $MockComic::ENGLISH => "beer $i",
            },
            $MockComic::SERIES => {
                $MockComic::DEUTSCH => 'brauen',
                $MockComic::ENGLISH => 'brewing',
            },
        );
        $comic->{href}{'Deutsch'} = "comics/bier$i.html";
        $comic->{href}{'English'} = "comics/beer$i.html";
        $comic->{modified} = "2023-11-0$i";
        push @comics, $comic;
    }
}


sub default_configuration : Tests {
    my $series = Comic::Out::Series->new();
    is($series->{settings}->{collect}, 'series', 'wrong meta data');
}


sub configure_collect_rejects_array_and_hash : Tests {
    eval {
        Comic::Out::Series->new(collect => ['series', 'other']);
    };
    like($@, qr{Comic::Out::Series}, 'should have module name');
    like($@, qr{\bscalar\b}i, 'should say what is wrong');

    eval {
        Comic::Out::Series->new(collect => { 'series' => 1 });
    };
    like($@, qr{\bscalar\b}i, 'should say what is wrong');
}


sub configure_collect_scalar : Tests {
    my $series = Comic::Out::Series->new(collect => 's');
    is($series->{settings}->{collect}, 's');
}


sub ignores_comic_without_series_meta_data : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "beer",
        },
    );

    my $series = Comic::Out::Series->new();
    $series->generate($comic);
    $series->generate($comics[0]);
    $series->generate_all($comic, $comics[0]);

    is_deeply($comic->{series}->{English}, {});
    is_deeply($comic->{warnings}, [], 'should not have warnings');
}


sub ignores_empty_meta_data_hash : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "beer",
        },
        $MockComic::SERIES => {
        },
    );

    my $series = Comic::Out::Series->new();
    $series->generate($comic);
    $series->generate($comics[0]);
    $series->generate_all($comic, $comics[0]);

    is_deeply($comic->{series}->{English}, {});
    is_deeply($comic->{warnings}, [], 'should not have warnings');
}


sub nice_error_message_if_series_meta_data_is_not_a_hash : Tests {
    my $oops = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Oops',
        },
        $MockComic::JSON => '"series": "not a language hash",',
    );

    my $series = Comic::Out::Series->new();
    $series->generate($oops);

    my $msg = $oops->{warnings}[0];
    like($msg, qr{\bmap\b}i, 'should say what is wrong');
    like($msg, qr{\bseries\b}i, 'should name the bad metadata');
}


sub nice_error_message_if_series_meta_data_per_language_is_not_a_scalar : Tests {
    my $oops = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Oops',
        },
        $MockComic::JSON => '"series": {"English": ["beer"]},',
    );

    my $series = Comic::Out::Series->new();
    $series->generate($oops);

    my $msg = $oops->{warnings}[0];
    like($msg, qr{\bsingle\b}i, 'should say what is wrong');
    like($msg, qr{\bseries\b}i, 'should name the bad metadata');
    like($msg, qr{\bEnglish\b}i, 'should include the language');
}


sub no_series_links_if_not_enough_comics : Tests {
    my $series = Comic::Out::Series->new();
    $series->generate($comics[0]);
    $series->generate_all($comics[0]);

    is_deeply($comics[0]->{series}{'Deutsch'}, {});
    is_deeply($comics[0]->{series}{'English'}, {});
}


sub adds_first_prev_next_last_links_to_comic : Tests {
    my $series = Comic::Out::Series->new();
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    is_deeply($comics[0]->{series}{'Deutsch'}, {
        'next' => 'comics/bier2.html',
        'last' => 'comics/bier3.html',
    });
    is_deeply($comics[1]->{series}{'Deutsch'}, {
        'first' => 'comics/bier1.html',
        'prev' => 'comics/bier1.html',
        'next' => 'comics/bier3.html',
        'last' => 'comics/bier3.html',
    });
    is_deeply($comics[2]->{series}{'Deutsch'}, {
        'first' => 'comics/bier1.html',
        'prev' => 'comics/bier2.html',
    });
    is_deeply($comics[0]->{series}{'English'}, {
        'next' => 'comics/beer2.html',
        'last' => 'comics/beer3.html',
    });
    is_deeply($comics[1]->{series}{'English'}, {
        'first' => 'comics/beer1.html',
        'prev' => 'comics/beer1.html',
        'next' => 'comics/beer3.html',
        'last' => 'comics/beer3.html',
    });
    is_deeply($comics[2]->{series}{'English'}, {
        'first' => 'comics/beer1.html',
        'prev' => 'comics/beer2.html',
    });
}


sub does_not_refer_to_comics_without_title : Tests {
    my $untitled = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => '',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'brewing',
        },
    );
    my $series = Comic::Out::Series->new();
    $series->generate($untitled);
    $series->generate($_) foreach (@comics);
    $series->generate_all($untitled, @comics);

    is_deeply($comics[2]->{series}{'English'}, {
        'prev' => 'comics/beer2.html',
        'first' => 'comics/beer1.html',
    });
    is($untitled->{series}{'English'}, undef);  # comics without title get ignored
}


sub does_not_refer_to_comic_that_is_not_yet_published : Tests {
    my $unpublished = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Publish me',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'brewing',
        },
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::PUBLISHED_WHERE => 'web',
    );
    my $series = Comic::Out::Series->new();

    $series->generate($unpublished);
    $series->generate($_) foreach (@comics);
    $series->generate_all($unpublished, @comics);

    is_deeply($comics[2]->{series}{'English'}, {
        'prev' => 'comics/beer2.html',
        'first' => 'comics/beer1.html',
    });
    is_deeply($unpublished->{series}{'English'}, {
        'first' => 'comics/beer1.html',
        'prev' => 'comics/beer3.html',
    });
}


sub does_not_refer_to_comic_that_is_not_published_on_the_web : Tests {
    my $elsewhere = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Published elsewhere',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'whatever',
        },
        $MockComic::PUBLISHED_WHEN => '2020-01-01',
        $MockComic::PUBLISHED_WHERE => 'elsewhere',
    );
    my $series = Comic::Out::Series->new();
    $series->generate($elsewhere);
    $series->generate($_) foreach (@comics);
    $series->generate_all($elsewhere, @comics);

    is_deeply($comics[2]->{series}{'English'}, {
        'prev' => 'comics/beer2.html',
        'first' => 'comics/beer1.html',
    });
    is_deeply($elsewhere->{series}{'English'}, {});
}


sub ignores_languages_without_series : Tests {
    my $one_language_series= MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => "Bier 0",
            $MockComic::ENGLISH => "beer 0",
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'brewing',
        },
    );
    $one_language_series->{href}{'Deutsch'} = "comics/nur-englisch.html";
    $one_language_series->{href}{'English'} = "comics/only-english.html";
    $one_language_series->{modified} = "2023-10-01";

    my $series = Comic::Out::Series->new();
    $series->generate($one_language_series);
    $series->generate($comics[0]);
    $series->generate_all($one_language_series, $comics[0]);

    is_deeply($one_language_series->{series}, {
        'English' => {
            'next' => 'comics/beer1.html', 'last' => 'comics/beer1.html',
        },
        'Deutsch' => {
            # empty
        },
    });
    is_deeply($comics[0]->{series}, {
        'English' => {
            'prev' => 'comics/only-english.html', 'first' => 'comics/only-english.html',
        },
        'Deutsch' => {
            # empty
        },
    });
}


sub warn_if_no_series_tag_seen : Tests {
    my $series = Comic::Out::Series->new('collect' => 'the_series');

    $series->generate($_) foreach (@comics);
    eval {
        $series->generate_all(@comics);
    };

    like($@, qr{Comic::Out::Series}, 'should mention module name');
    like($@, qr{no comics}, 'should say what was wrong');
    like($@, qr{the_series}, 'should mention the bad series name');
}
