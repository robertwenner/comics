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
            $MockComic::PUBLISHED_WHEN => "2023-10-0$i",
        );
        $comic->{href}{'Deutsch'} = "comics/bier$i.html";
        $comic->{href}{'English'} = "comics/beer$i.html";
        $comic->{modified} = "2023-11-0$i";
        push @comics, $comic;
    }
}


sub default_configuration : Tests {
    my $series = Comic::Out::Series->new();
    is($series->{settings}->{collect}, 'series', 'wrong metadata');
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


sub configure_rejects_invalid_min_count : Tests {
    eval {
        Comic::Out::Series->new('min-count' => 'whatever');
    };
    like($@, qr{Comic::Out::Series}, 'should mention module name');
    like($@, qr{\bmin-count\b}, 'should mention setting');
    like($@, qr{\bnumber\b}, 'should say what is wrong');

    eval {
        Comic::Out::Series->new('min-count' => '-1');
    };
    like($@, qr{Comic::Out::Series}, 'should mention module name');
    like($@, qr{\bmin-count\b}, 'should mention setting');
    like($@, qr{\bpositive\b}, 'should say what is wrong');
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
    $series->generate($_) foreach (reverse @comics);
    $series->generate_all(reverse @comics);

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


sub complains_if_no_series_series_seen : Tests {
    my $series = Comic::Out::Series->new('collect' => 'the_series');

    $series->generate($_) foreach (@comics);
    eval {
        $series->generate_all(@comics);
    };

    like($@, qr{Comic::Out::Series}, 'should mention module name');
    like($@, qr{no comics}, 'should say what was wrong');
    like($@, qr{the_series}, 'should mention the bad series name');
}


sub configure_one_template_for_all_languages : Tests {
    MockComic::fake_file('series.templ', 'template goes here');
    my $series = Comic::Out::Series->new(template => 'series.templ');
    is($series->get_setting('template', 'English'), 'series.templ');
    is($series->get_setting('template', 'Deutsch'), 'series.templ');
    is($series->get_setting('template', 'whatever, really'), 'series.templ');
}


sub configure_template_per_language : Tests {
    MockComic::fake_file('series.en', 'template goes here');
    my $series = Comic::Out::Series->new(template => { 'English' => 'series.en' });
    is($series->get_setting('template', 'English'), 'series.en');
    eval {
        $series->get_setting('template', 'unknown language');
    };
    like($@, qr{template}i, 'should say what is wrong');
    like($@, qr{unknown language}, 'should mention the language');
}


sub configure_template_rejects_array : Tests {
    eval {
        Comic::Out::Series->new(template => []);
    };
    like($@, qr{\btemplate\b}i, 'should say what setting it complains about');
    like($@, qr{\bscalar\b}i, 'should say what is wrong');
}


sub configure_outdir_single_name_for_all_languages : Tests {
    my $series = Comic::Out::Series->new(
        template => 'series.templ',
        outdir => 'series',
    );
    is($series->get_setting('outdir', 'English'), 'series');
    is($series->get_setting('outdir', 'Deutsch'), 'series');
    is($series->get_setting('outdir', 'whatever'), 'series');
}


sub configure_outdir_per_language : Tests {
    my $series = Comic::Out::Series->new(
        template => 'series.templ',
        outdir => {
            'English' => 'series',
            'Deutsch' => 'schlagwortwolke',
        },
    );
    is($series->get_setting('outdir', 'English'), 'series');
    is($series->get_setting('outdir', 'Deutsch'), 'schlagwortwolke');
    eval {
        $series->get_setting('outdir', 'whatever');
    };
    like($@, qr{outdir}, 'should mention setting');
    like($@, qr{defined}, 'should say what is wrong');
    like($@, qr{whatever}, 'should mention language');
}


sub configure_outdir_rejects_array : Tests {
    eval {
        Comic::Out::Series->new(template => 'series.templ', outdir => [1, 2, 3]);
    };
    like($@, qr{outdir}, 'should mention setting');
    like($@, qr{array}, 'should say what is wrong');
}


sub outdir_not_given_uses_default : Tests {
    my $series = Comic::Out::Series->new(template => 'series.templ');
    is($series->get_setting('outdir', 'English'), 'series');
    is($series->get_setting('outdir', 'Deutsch'), 'series');
}


sub creates_series_page : Tests {
    my $content = << 'TEMPL';
        <h1>[% series %]</h1>
        [% FOREACH c IN comics %]
            <a href="[% c.href %]">[% c.title %]</a>
        [% END %]
TEMPL
    MockComic::fake_file('series.templ', $content);

    my $series = Comic::Out::Series->new(template => 'series.templ', outdir => 'series');
    $series->generate($_) foreach (reverse @comics);
    $series->generate_all(@comics);

    MockComic::assert_made_some_dirs('generated/web/deutsch/series', 'generated/web/english/series');
    MockComic::assert_wrote_file('generated/web/deutsch/series/brauen.html', qr{
        <h1>brauen</h1>\s+
        <a\shref="comics/bier1\.html">Bier\s1</a>\s+
        <a\shref="comics/bier2\.html">Bier\s2</a>\s+
        <a\shref="comics/bier3\.html">Bier\s3</a>
    }mx);

    MockComic::assert_wrote_file('generated/web/english/series/brewing.html', qr{
        <h1>brewing</h1>\s+
        <a\shref="comics/beer1\.html">beer\s1</a>\s+
        <a\shref="comics/beer2\.html">beer\s2</a>\s+
        <a\shref="comics/beer3\.html">beer\s3</a>
    }mx);
}


sub defines_series_page_template_variables : Tests {
    my $content = << 'TEMPL';
        url: [% url %]
        language: [% language %]
        root: [% root %]
        last_modified: [% last_modified %]
TEMPL
    MockComic::fake_file('series.templ', $content);
    my $series = Comic::Out::Series->new(template => 'series.templ', outdir => 'series');

    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/english/series/brewing.html', qr{url: /series/brewing.html}m);
    MockComic::assert_wrote_file('generated/web/english/series/brewing.html', qr{language: english}m);
    MockComic::assert_wrote_file('generated/web/english/series/brewing.html', qr{root: \.\./}m);
    MockComic::assert_wrote_file('generated/web/english/series/brewing.html', qr{last_modified: \d{4}-\d{2}-\d{2}}m);
}


sub adds_series_page_links_to_comics : Tests {
    MockComic::fake_file('series.templ', '...');

    my $series = Comic::Out::Series->new(template => 'series.templ', outdir => 'series');
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    my %expected = (
        'Deutsch' => {
            'brauen' => 'series/brauen.html',
        },
        'English' => {
            'brewing' => 'series/brewing.html',
        },
    );
    foreach my $comic (@comics) {
        is_deeply($comic->{series_page}, \%expected);
    }
}


sub sanitizes_series_page_name : Tests {
    MockComic::fake_file('series.templ', '...');
    my $series = Comic::Out::Series->new(template => 'series.templ', outdir => 'series', 'min-count' => 0);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => '*&lt;hops/malt&gt;...: &amp; so on , right!?',
        },
    );

    $series->generate($comic);
    $series->_generate_series_pages($comic);

    MockComic::assert_wrote_file('generated/web/english/series/_hops_malt_so_on_right_.html', qr{.+});
}


sub avoids_series_page_file_name_collisions : Tests {
    MockComic::fake_file('series.templ', '[% series %]');
    foreach my $series ('og/fg', 'og,fg') {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => $series,
            },
            $MockComic::SERIES => {
                $MockComic::ENGLISH => $series,
            },
        );
        push @comics, $comic;
    }

    my $series = Comic::Out::Series->new(template => 'series.templ', 'min-count' => 0);
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/english/series/og_fg.html', 'og,fg');
    MockComic::assert_wrote_file('generated/web/english/series/og_fg_0.html', 'og/fg');
}


sub avoids_series_page_file_name_collisions_language_independently : Tests {
    MockComic::fake_file('series.templ', '[% series %]');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
            $MockComic::DEUTSCH => 'Bier',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'ipa',
            $MockComic::DEUTSCH => 'ipa',
        },
    );

    my $series = Comic::Out::Series->new(template => 'series.templ', 'min-count' => 1);
    $series->generate($comic);
    $series->generate_all($comic);

    MockComic::assert_wrote_file('generated/web/english/series/ipa.html', 'ipa');
    MockComic::assert_wrote_file('generated/web/deutsch/series/ipa.html', 'ipa');
}


sub adds_empty_series_for_unpublished_comic : Tests {
    MockComic::fake_file('series.templ', '');
    my $unpublished = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Publish me',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::PUBLISHED_WHERE => 'web',
    );
    $unpublished->{modified} = '2023-01-01';

    my $series = Comic::Out::Series->new(template => 'series.templ', outdir => 'series', 'min-count' => 1);
    $series->generate($unpublished);
    $series->generate_all($unpublished);

    is_deeply($unpublished->{series}, { 'English' => {} });
    is_deeply($unpublished->{series_page}, { 'English' => {} });
}


sub no_series_page_if_count_too_low : Tests {
    MockComic::fake_file('series.templ', '[% series %]');

    my $series = Comic::Out::Series->new('min-count' => 2, 'template' => 'series.templ');
    $series->generate($comics[0]);
    $series->_generate_series_pages($comics[0]);

    MockComic::assert_wrote_file('generated/web/english/series/brewing.html', undef);
    MockComic::assert_wrote_file('generated/web/english/series/brauen.html', undef);
}


sub does_not_put_links_to_skipped_series_page_in_comics : Tests {
    my $series = Comic::Out::Series->new('min-count' => 2, 'template' => 'series.templ');
    $series->generate($comics[0]);
    $series->_put_series_pages_link_in_comics($comics[0]);

    is_deeply($comics[0]->{series_page}, { 'Deutsch' => {}, 'English' => {} });
}


sub series_page_last_modified_date_is_latest_comic_date : Tests {
    my $series = Comic::Out::Series->new();
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    is_deeply($series->{last_modified}, {
        'Deutsch' => {'brauen' => '2023-11-03'},
        'English' => {'brewing' => '2023-11-03'}
    });
}


sub warns_about_empty_series : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Funny comic",
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => '',
        },
    );

    my $series = Comic::Out::Series->new();
    $series->generate($comic);

    my $msg = $comic->{warnings}[0];
    like($msg, qr{\bempty\b}i, 'should say what is wrong');
    like($msg, qr{\bseries\b}, 'should mention the type');
    like($msg, qr{\bEnglish\b}, 'should include the language');
}


sub warns_about_whitespace_only_series : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Funny comic",
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => "   \t",
        },
    );

    my $series = Comic::Out::Series->new();
    $series->generate($comic);

    my $msg = $comic->{warnings}[0];
    like($msg, qr{\bempty\b}i, 'should say what is wrong');
    like($msg, qr{\bseries\b}, 'should mention the metadata name');
    like($msg, qr{\bEnglish\b}, 'should include the language');
}


sub croaks_if_comic_does_not_have_the_configured_meta_data : Tests {
    my $series = Comic::Out::Series->new(collect => 'not-series');
    $series->generate($_) foreach (@comics);
    eval {
        $series->generate_all(@comics);
    };
    like($@, qr{\bno comic}i, 'should say what is wrong');
    like($@, qr{\bmetadata\b}i, 'should say what is wrong');
    like($@, qr{\bnot-series\b}, 'should mention the series name');
}


sub rejects_array_for_series_page_index : Tests {
    eval {
        Comic::Out::Series->new(index => []);
    };
    like($@, qr{\bindex\b}, 'should mention the setting');
    like($@, qr{\barray\b}, 'should say what is wrong');
}


sub accepts_one_series_page_index_template_for_all_languages : Tests {
    my $series = Comic::Out::Series->new(template => 'page.templ', index => 'index.templ');
    is($series->get_setting('index', 'English'), 'index.templ');
    is($series->get_setting('index', 'Deutsch'), 'index.templ');
    is($series->get_setting('index', 'whatever, really'), 'index.templ');
}


sub accepts_per_language_series_page_index_templates : Tests {
    my $series = Comic::Out::Series->new(template => 'page.templ', index => { 'English' => 'index.templ' });
    is($series->get_setting('index', 'English'), 'index.templ');
    eval {
        $series->get_setting('index', 'unknown language');
    };
    like($@, qr{index}i, 'should say what is wrong');
    like($@, qr{unknown language}, 'should mention the language');
}


sub rejects_index_template_without_series_pages_template : Tests {
    eval {
        Comic::Out::Series->new(index => 'index.templ');
    };
    like($@, qr{\bComic::Out::Series\b}, 'should have module name');
    like($@, qr{\bindex\b}, 'should mention the setting');
    like($@, qr{\btemplate\b}, 'should mention the missing setting');
}


sub writes_index_series_page : Tests {
    MockComic::fake_file('page.templ', '...');
    my $index = << 'TEMPL';
        [% FOREACH sp IN series_pages %]
            [% sp.title %] -> [% root %][% sp.href %]
        [% END %]
TEMPL
    MockComic::fake_file('index.templ', $index);

    my $series = Comic::Out::Series->new(template => 'page.templ', index => 'index.templ');
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/english/series/index.html',
        qr{\s*brewing -> \.\./series/brewing\.html\s*}m);
}


sub index_page_sorted_alphabetically : Tests {
    MockComic::fake_file('page.templ', '...');
    my $index = << 'TEMPL';
        [% FOREACH sp IN series_pages %]
            [% sp.title %]
        [% END %]
TEMPL
    MockComic::fake_file('index.templ', $index);

    my $series = Comic::Out::Series->new(template => 'page.templ', index => 'index.templ', 'min-count' => 0);
    $comics[0]->{meta_data}->{series}->{English} = 'lager';
    $comics[1]->{meta_data}->{series}->{English} = 'ale';
    $comics[2]->{meta_data}->{series}->{English} = 'Amber';
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/english/series/index.html',
        qr{ale\s+Amber\s+lager});
}


sub index_page_does_not_include_series_under_min_count : Tests {
    MockComic::fake_file('page.templ', '...');
    my $index = << 'TEMPL';
        Series:
        [% FOREACH sp IN series_pages %]
            [% sp.title %]
        [% END %]
TEMPL
    MockComic::fake_file('index.templ', $index);

    my $series = Comic::Out::Series->new(template => 'page.templ', index => 'index.templ', 'min-count' => 10);
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/deutsch/series/index.html', qr{^\s*Series:\s*$}m);
    MockComic::assert_wrote_file('generated/web/english/series/index.html', qr{^\s*Series:\s*$}m);
}


sub last_modified_date_in_series_index_is_latest_comic_modification_one_series : Tests {
    MockComic::fake_file('page.templ', '...');
    MockComic::fake_file('index.templ', '[% last_modified %]');
    $comics[1]->{modified} = '2023-11-11';

    my $series = Comic::Out::Series->new(template => 'page.templ', index => 'index.templ');
    $series->generate($_) foreach (@comics);
    $series->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/english/series/index.html', '2023-11-11');
}


sub index_page_has_last_modified_of_all_series : Tests {
    MockComic::fake_file('series.templ', '...');
    MockComic::fake_file('index.templ', '[% last_modified %]');
    my $other= MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Other',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'other',
        },
    );
    $other->{modified} = '2024-01-01';

    my $series = Comic::Out::Series->new(template => 'series.templ', index => 'index.templ', 'min-count' => 0);

    $series->generate($_) foreach ($other, @comics);
    $series->generate_all($other, @comics);

    MockComic::assert_wrote_file('generated/web/english/series/index.html', '2024-01-01');
}


sub reserves_index_html_for_index_page : Tests {
    MockComic::fake_file('page.templ', 'page');
    MockComic::fake_file('index.templ', 'index');

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::SERIES => {
            $MockComic::ENGLISH => 'index',
        },
    );

    my $series = Comic::Out::Series->new(template => 'page.templ', index => 'index.templ', 'min-count' => 1);
    $series->generate($comic);
    $series->generate_all($comic);

    MockComic::assert_wrote_file('generated/web/english/series/index.html', 'index');
    MockComic::assert_wrote_file('generated/web/english/series/index_0.html', 'page');
}
