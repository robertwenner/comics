use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Out::Tags;

__PACKAGE__->runtests() unless caller;

my $max_beer_brewing;
my $max_paul_beer_brewing;


sub set_up : Test(setup) {
    MockComic::set_up();

    $max_beer_brewing = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Max Bier brauen',
            $MockComic::ENGLISH => 'Max beer brewing',
        },
        $MockComic::TAGS => {
            $MockComic::DEUTSCH => ['Bier', 'Brauen'],
            $MockComic::ENGLISH => ['beer', 'brewing'],
        },
        $MockComic::WHO => {
            $MockComic::DEUTSCH => ['Max'],
            $MockComic::ENGLISH => ['Max'],
        },
    );
    $max_beer_brewing->{href}{'Deutsch'} = 'comics/max-bier-brauen.html';
    $max_beer_brewing->{href}{'English'} = 'comics/max-beer-brewing.html';
    $max_beer_brewing->{modified} = '2023-01-01';

    $max_paul_beer_brewing = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Max Paul Bier brauen',
            $MockComic::ENGLISH => 'Max Paul beer brewing',
        },
        $MockComic::TAGS => {
            $MockComic::DEUTSCH => ['Bier', 'Brauen'],
            $MockComic::ENGLISH => ['beer', 'brewing'],
        },
        $MockComic::WHO => {
            $MockComic::DEUTSCH => ['Max', 'Paul'],
            $MockComic::ENGLISH => ['Max', 'Paul'],
        },
    );
    $max_paul_beer_brewing->{href}{'Deutsch'} = 'comics/max-paul-bier-brauen.html';
    $max_paul_beer_brewing->{href}{'English'} = 'comics/max-paul-beer-brewing.html';
    $max_paul_beer_brewing->{modified} = '2023-01-01';
}


sub default_configuration : Tests {
    my $tags = Comic::Out::Tags->new();
    is_deeply(${$tags->{settings}}{collect}, ['tags']);
}


sub configure_collect_array : Tests {
    my $tags = Comic::Out::Tags->new(collect => ['who', 'tags']);
    is_deeply(${$tags->{settings}}{collect}, ['who', 'tags']);
}


sub configure_collect_scalar : Tests {
    my $tags = Comic::Out::Tags->new(collect => 'who');
    is_deeply(${$tags->{settings}}{collect}, ['who']);
}


sub configure_collect_rejects_hash : Tests {
    eval {
        Comic::Out::Tags->new(collect => { 'tags' => 1 });
    };
    like($@, qr{\barray\b}i, 'should say what is wrong');
}


sub adds_tags_to_comic : Tests {
    my $tags = Comic::Out::Tags->new(collect => 'tags');
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->generate_all($max_beer_brewing, $max_paul_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {
        'Bier' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
        'Brauen' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
    });
    is_deeply($max_beer_brewing->{tags}{'English'}, {
        'beer' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
        'brewing' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
    });
}


sub adds_tags_and_who_to_comic : Tests {
    my $tags = Comic::Out::Tags->new(collect => ['tags', 'who']);
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->generate_all($max_beer_brewing, $max_paul_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {
        'Bier' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
        'Brauen' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
        'Max' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
    });
    is_deeply($max_beer_brewing->{tags}{'English'}, {
        'beer' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
        'brewing' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
        'Max' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
    });
}


sub ignores_comic_without_tags : Tests {
    my $tags = Comic::Out::Tags->new(collect => ['something']);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {});
    is_deeply($max_beer_brewing->{tags}{'English'}, {});
}


sub ignores_comic_with_empty_tags : Tests {
    my $no_tags = MockComic::make_comic(
        $MockComic::JSON => '"tags": {},',
    );
    $max_paul_beer_brewing->{modified} = '2023-01-01';

    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($no_tags);
    $tags->generate_all($no_tags);

    is_deeply($no_tags->{tags}{'English'}, {});
}


sub nice_error_message_if_tags_meta_data_is_not_an_hash : Tests {
    my $oops = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Oops',
        },
        $MockComic::JSON => '"tags": "no language hash",',
    );

    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($oops);

    my $msg = $oops->{warnings}[0];
    like($msg, qr{\bhash\b}i, 'should say what is wrong');
    like($msg, qr{\blanguages\b}i, 'should say what is wrong');
    like($msg, qr{\btags\b}i, 'should name the bad metadata');
}


sub nice_error_message_if_tags_meta_data_per_language_is_not_an_array : Tests {
    my $oops = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Oops',
        },
        $MockComic::JSON => '"tags": {"English": "beer"},',
    );

    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($oops);

    my $msg = $oops->{warnings}[0];
    like($msg, qr{\barray\b}i, 'should say what is wrong');
    like($msg, qr{\btags\b}i, 'should name the bad metadata');
    like($msg, qr{\bEnglish\b}i, 'should include the language');
}


sub does_not_refer_to_comics_without_title : Tests {
    my $untitled = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => '',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
    );
    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($untitled);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($untitled, $max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is($untitled->{tags}{'English'}, undef);
}


sub does_not_refer_to_comic_that_is_not_yet_published : Tests {
    my $unpublished = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Publish me',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::PUBLISHED_WHERE => 'web',
    );
    my $tags = Comic::Out::Tags->new(collect => ['tags']);

    $tags->generate($unpublished);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($unpublished, $max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is_deeply($unpublished->{tags}{'English'}, {});
}


sub does_not_refer_to_comic_that_is_not_published_on_the_web : Tests {
    my $elsewhere = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Published elsewhere',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
        $MockComic::PUBLISHED_WHEN => '2020-01-01',
        $MockComic::PUBLISHED_WHERE => 'elsewhere',
    );
    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($elsewhere);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($elsewhere, $max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is_deeply($elsewhere->{tags}{'English'}, {});
}


sub configure_one_template_for_all_languages : Tests {
    MockComic::fake_file('tagcloud.templ', 'template goes here');
    my $tags = Comic::Out::Tags->new(template => 'tagcloud.templ');
    is($tags->_get_tag_page_template('English'), 'tagcloud.templ');
    is($tags->_get_tag_page_template('Deutsch'), 'tagcloud.templ');
    is($tags->_get_tag_page_template('whatever, really'), 'tagcloud.templ');
}


sub configure_template_per_language : Tests {
    MockComic::fake_file('tagcloud.en', 'template goes here');
    my $tags = Comic::Out::Tags->new(template => { 'English' => 'tagcloud.en' });
    is($tags->_get_tag_page_template('English'), 'tagcloud.en');
    eval {
        $tags->_get_tag_page_template('unknown language');
    };
    like($@, qr{template}i, 'should say what is wrong');
    like($@, qr{unknown language}, 'should mention the language');
}


sub configure_template_rejects_array : Tests {
    eval {
        Comic::Out::Tags->new(template => []);
    };
    like($@, qr{\btemplate\b}i, 'should say what setting it complains about');
    like($@, qr{\bscalar\b}i, 'should say what is wrong');
}


sub configure_outdir_single_name_for_all_languages : Tests {
    my $tags = Comic::Out::Tags->new(
        template => 'tagcloud.templ',
        outdir => 'tagcloud',
    );
    is($tags->_get_outdir('English'), 'tagcloud');
    is($tags->_get_outdir('Deutsch'), 'tagcloud');
    is($tags->_get_outdir('whatever'), 'tagcloud');
}


sub configure_outdir_per_language : Tests {
    my $tags = Comic::Out::Tags->new(
        template => 'tagcloud.templ',
        outdir => {
            'English' => 'tagcloud',
            'Deutsch' => 'schlagwortwolke',
        },
    );
    is($tags->_get_outdir('English'), 'tagcloud');
    is($tags->_get_outdir('Deutsch'), 'schlagwortwolke');
    eval {
        $tags->_get_outdir('whatever');
    };
    like($@, qr{outdir}, 'should mention setting');
    like($@, qr{defined}, 'should say what is wrong');
    like($@, qr{whatever}, 'should mention language');
}


sub configure_outdir_rejects_array : Tests {
    eval {
        Comic::Out::Tags->new(template => 'tags.templ', outdir => [1, 2, 3]);
    };
    like($@, qr{outdir}, 'should mention setting');
    like($@, qr{array}, 'should say what is wrong');
}


sub outdir_not_given_uses_default : Tests {
    my $tags = Comic::Out::Tags->new(template => 'tagcloud.templ');
    is($tags->_get_outdir('English'), 'tags');
    is($tags->_get_outdir('Deutsch'), 'tags');
}


sub creates_tags_page : Tests {
    my $content = << 'TEMPL';
        <h1>[% tag %] ([% count %])</h1>
        [% FOREACH c IN comics %]
            <a href="[% c.value %]">[% c.key %]</a>
        [% END %]
TEMPL
    MockComic::fake_file('tags.templ', $content);
    my $tags = Comic::Out::Tags->new(template => 'tags.templ', outdir => 'tags');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
            $MockComic::DEUTSCH => 'Bier',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['brewing'],
            $MockComic::DEUTSCH => ['brauen'],
        },
    );
    $comic->{modified} = '2023-01-01';

    $tags->generate($comic);
    $tags->_write_tags_pages($comic);

    MockComic::assert_made_some_dirs('generated/web/deutsch/tags', 'generated/web/english/tags');
    MockComic::assert_wrote_file('generated/web/deutsch/tags/brauen.html',
        qr{<h1>brauen \(1\)</h1>}m);
    MockComic::assert_wrote_file('generated/web/deutsch/tags/brauen.html',
        qr{<a href="comics/bier\.html">Bier</a>}m);

    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html',
        qr{<h1>brewing \(1\)</h1>}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html',
        qr{<a href="comics/beer\.html">beer</a>}m);
}


sub defines_tags_page_template_variables : Tests {
    my $content = << 'TEMPL';
        url: [% url %]
        language: [% language %]
        root: [% root %]
        last_modified: [% last_modified %]
        count: [% count %]
        min: [% min %]
        max: [% max %]
TEMPL
    MockComic::fake_file('tags.templ', $content);
    my $tags = Comic::Out::Tags->new(template => 'tags.templ', outdir => 'tags');

    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->generate_all($max_beer_brewing, $max_paul_beer_brewing);

    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{url: /tags/brewing.html}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{language: english}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{root: \.\./}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{last_modified: \d{4}-\d{2}-\d{2}}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{count: 2}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{min: 2}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{max: 2}m);
}


sub adds_tag_page_links_to_comic : Tests {
    MockComic::fake_file('tags.templ', '...');
    my $tags = Comic::Out::Tags->new(template => 'tags.templ', outdir => 'tags');

    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->generate_all($max_beer_brewing, $max_paul_beer_brewing);

    my %expected = (
        'Deutsch' => {
            'Bier' => 'tags/Bier.html',
            'Brauen' => 'tags/Brauen.html',
        },
        'English' => {
            'beer' => 'tags/beer.html',
            'brewing' => 'tags/brewing.html',
        },
    );
    is_deeply($max_beer_brewing->{tags_page}, \%expected);
    is_deeply($max_paul_beer_brewing->{tags_page}, \%expected);
}


sub sanitizes_tag_page_name : Tests {
    MockComic::fake_file('tags.templ', '...');
    my $tags = Comic::Out::Tags->new(template => 'tags.templ', outdir => 'tags');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['*&lt;hops/malt&gt;...: &amp; so on , right!?'],
        },
    );
    $comic->{modified} = '2023-01-01';

    $tags->generate($comic);
    $tags->_write_tags_pages($comic);

    MockComic::assert_wrote_file('generated/web/english/tags/_hops_malt_so_on_right_.html', qr{.+});
}


sub avoids_tag_page_file_name_collisions : Tests {
    MockComic::fake_file('tags.templ', '[% FOREACH c IN comics %][% c.key %][% END %]');
    my @comics;
    foreach my $tag ('og/fg', 'og,fg') {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => $tag,
            },
            $MockComic::TAGS => {
                $MockComic::ENGLISH => [$tag],
            },
        );
        push @comics, $comic;
    }

    my $tags = Comic::Out::Tags->new(template => 'tags.templ');
    foreach my $comic (@comics) {
        $tags->generate($comic);
    }
    $tags->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/english/tags/og_fg.html', 'og,fg');
    MockComic::assert_wrote_file('generated/web/english/tags/og_fg_0.html', 'og/fg');
}


sub avoids_tag_page_file_name_collisions_language_indepdently : Tests {
    MockComic::fake_file('tags.templ', '[% FOREACH c IN comics %][% c.key %][% END %]');
    my @comics;
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => 'beer',
                $MockComic::DEUTSCH => 'Bier',
            },
            $MockComic::TAGS => {
                $MockComic::ENGLISH => ['ipa'],
                $MockComic::DEUTSCH => ['ipa'],
            },
        );
        push @comics, $comic;

    my $tags = Comic::Out::Tags->new(template => 'tags.templ');
    $tags->generate($comic);
    $tags->generate_all($comic);

    MockComic::assert_wrote_file('generated/web/english/tags/ipa.html', 'beer');
    MockComic::assert_wrote_file('generated/web/deutsch/tags/ipa.html', 'Bier');
}


sub adds_empty_tags_for_unpublished_comic : Tests {
    MockComic::fake_file('tags.templ', '');
    my $unpublished = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Publish me',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::PUBLISHED_WHERE => 'web',
    );
    $unpublished->{modified} = '2023-01-01';
    my $tags = Comic::Out::Tags->new(template => 'tags.templ', outdir => 'tags');

    $tags->generate($unpublished);
    $tags->generate_all($unpublished);

    is_deeply($unpublished->{tags}, { 'English' => {} });
    is_deeply($unpublished->{tags_page}, { 'English' => {} });
    is_deeply($tags->{tags}->{English}, {});
    is_deeply($tags->{tag_page}, undef);
}


sub rejects_bad_min_count : Tests {
   eval {
        Comic::Out::Tags->new('min-count' => 'yes');
    };
    like($@, qr{min-count}, 'should mention the setting');
    like($@, qr{\bnumber\b}i, 'should say what is wrong');

    eval {
        Comic::Out::Tags->new('min-count' => []);
    };
    like($@, qr{min-count}, 'should mention the setting');
    like($@, qr{\barray\b}i, 'should say what is wrong');

    eval {
        Comic::Out::Tags->new('min-count' => {});
    };
    like($@, qr{min-count}, 'should mention the setting');
    like($@, qr{\bhash\b}i, 'should say what is wrong');

    eval {
        Comic::Out::Tags->new('min-count' => '-1');
    };
    like($@, qr{min-count}, 'should mention the setting');
    like($@, qr{\bpositive\b}i, 'should say what is wrong');
}


sub no_tags_page_if_count_too_low : Tests {
    my $template = 'tag page [% FOREACH c IN comics %][% c.value %]: [% c.key %][% END %]';
    MockComic::fake_file('tags.templ', $template);
    my $more_brewing = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'More brewing',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['skipped'],
        },
    );
    $more_brewing->{href}{'English'} = 'comics/more-brewing.html';
    $more_brewing->{modified} = '2023-01-01';

    my $tags = Comic::Out::Tags->new('min-count' => '2', 'template' => 'tags.templ');
    $tags->generate($more_brewing);
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->_write_tags_pages($more_brewing, $max_beer_brewing, $max_paul_beer_brewing);

    MockComic::assert_wrote_file('generated/web/english/tags/beer.html', qr{.+});
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{.+});
    MockComic::assert_wrote_file('generated/web/english/tags/skipped.html', undef);
}


sub does_not_put_links_to_skipped_tag_page_in_comics : Tests {
    my $tags = Comic::Out::Tags->new('min-count' => '3', 'template' => 'tags.templ');
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->_put_tags_in_comics($max_beer_brewing, $max_paul_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {});
    is_deeply($max_paul_beer_brewing->{tags}{'Deutsch'}, {});
    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is_deeply($max_paul_beer_brewing->{tags}{'English'}, {});
}


sub tag_page_last_modified_date_is_latest_comic_date : Tests {
    my @comics;
    for (my $i = 1; $i <= 3; $i++) {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => "number $i",
            },
            $MockComic::TAGS => {
                $MockComic::ENGLISH => ['beer'],
            },
        );
        $comic->{href}{'English'} = "comics/$i.html";
        $comic->{modified} = "2023-0$i-01";
        push @comics, $comic;
    }

    my $tags = Comic::Out::Tags->new();
    foreach my $c (@comics) {
        $tags->generate($c);
    }
    $tags->generate_all(@comics);

    is_deeply($tags->{last_modified}, {'English' => {'beer' => '2023-03-01'}});
}


sub puts_tag_counts_in_comic : Tests {
    my $tags = Comic::Out::Tags->new('template' => 'tags.templ');
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->_put_tags_in_comics($max_beer_brewing, $max_paul_beer_brewing);

    is_deeply($max_beer_brewing->{tag_count},
        {'Deutsch' => {'Bier' => 2, 'Brauen' => 2}, 'English' => {'beer' => 2, 'brewing' => 2}});
}


sub puts_min_and_max_counts_in_comic : Tests {
    my @comics;
    foreach my $i (3, 1, 2, 1, 3) {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => "number $i",
            },
            $MockComic::TAGS => {
                $MockComic::ENGLISH => ['beer', "tag$i"],
            },
        );
        $comic->{href}{'English'} = "comics/$i.html";
        $comic->{modified} = "2023-0$i-01";
        push @comics, $comic;
    }

    my $tags = Comic::Out::Tags->new();
    foreach my $c (@comics) {
        $tags->generate($c);
    }
    $tags->generate_all(@comics);

    is_deeply($comics[0]->{tag_min}, {'English' => 1});
    is_deeply($comics[0]->{tag_max}, {'English' => 5});
}


sub calculates_style_ranks_no_comics : Tests {
    my $tags = Comic::Out::Tags->new();

    $tags->generate_all();

    is_deeply($tags->{tag_rank}, {});
}


sub calculates_style_ranks_tag_only_used_once : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Funny comic",
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
    );

    my $tags = Comic::Out::Tags->new();

    $tags->generate($comic);
    $tags->generate_all($comic);

    is_deeply($tags->{tag_rank}, {'English' => { 'beer' => 'taglevel5' }});
    is_deeply($comic->{tag_rank}, {'English' => { 'beer' => 'taglevel5' }});
}


sub calculates_style_ranks_wide_spread : Tests {
    my $count = 0;
    my @comics;
    foreach my $i (qw{a a a a a a a   b b b b b   c c c   d d   e}) {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => "number $count",
            },
            $MockComic::TAGS => {
                $MockComic::ENGLISH => ["tag $i"],
            },
        );
        push @comics, $comic;
        $count++;
    }

    MockComic::fake_file('tagspage.templ', '...');
    my $tags = Comic::Out::Tags->new(template => 'tagspage.templ');
    foreach my $c (@comics) {
        $tags->generate($c);
    }
    $tags->generate_all(@comics);

    my %expected = (
        'English' => {
            'tag a' => 'taglevel5',  # 7 / 18 => (7 - 1) / (7 - 1) = 1
            'tag b' => 'taglevel4',  # 5 / 18 => (5 - 1) / 5 = 4 / 5 = 0.8
            'tag c' => 'taglevel2',  # 3 / 18 => (3 - 1) / 5 = 0.4
            'tag d' => 'taglevel1',  # 2 / 18 => (2 - 1) / 5 = 1 / 5 = 0.20
            'tag e' => 'taglevel1',  # 1 / 18 => (1 - 1) / 5 = 0
        },
    );
    is_deeply($tags->{tag_rank}, \%expected);
    is_deeply($comics[0]->{tag_rank}, \%expected);
    is_deeply($comics[0]->{all_tags_pages}, {
        'English' => {
            'tag a' => 'tags/tag_a.html',
            'tag b' => 'tags/tag_b.html',
            'tag c' => 'tags/tag_c.html',
            'tag d' => 'tags/tag_d.html',
            'tag e' => 'tags/tag_e.html',
        },
    });
}


sub calculates_style_ranks_honors_min_count : Tests {
    my $count = 0;
    my @comics;
    foreach my $i (qw{a a a a a a a   b b b b b   c c c   d d   e}) {
        my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => "number $count",
            },
            $MockComic::TAGS => {
                $MockComic::ENGLISH => ["tag $i"],
            },
        );
        push @comics, $comic;
        $count++;
    }

    MockComic::fake_file('tagspage.templ', '...');
    my $tags = Comic::Out::Tags->new(template => 'tagspage.templ', 'min-count' => 4);
    foreach my $c (@comics) {
        $tags->generate($c);
    }
    $tags->generate_all(@comics);

    my %expected = (
        'English' => {
            'tag a' => 'taglevel5',
            'tag b' => 'taglevel4',
        },
    );
    is_deeply($tags->{tag_rank}, \%expected);
    is_deeply($comics[0]->{tag_rank}, \%expected);
    is_deeply($comics[0]->{all_tags_pages}, {
        'English' => {
            'tag a' => 'tags/tag_a.html',
            'tag b' => 'tags/tag_b.html',
        },
    });
}


sub warns_about_empty_tags : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Funny comic",
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => [''],
        },
    );

    my $tags = Comic::Out::Tags->new();
    $tags->generate($comic);

    my $msg = $comic->{warnings}[0];
    like($msg, qr{\bempty\b}i, 'should say what is wrong');
    like($msg, qr{\btags\b}, 'should mention the tag type');
}


sub warns_about_whitespace_pnly_tags : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Funny comic",
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ["   \t"],
        },
    );

    my $tags = Comic::Out::Tags->new();
    $tags->generate($comic);

    my $msg = $comic->{warnings}[0];
    like($msg, qr{\bempty\b}i, 'should say what is wrong');
    like($msg, qr{\btags\b}, 'should mention the tag type');
}


sub warns_if_comic_does_not_have_the_configured_meta_data : Tests {
    # could be a typo: configure to pick up "tg" when ity should be "tag"
    # but then again an Out module should not check, or should it?
    # A check module does not know the Output module's configuration and purpose.
    my $tags = Comic::Out::Tags->new(collect => ['whatever']);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($max_beer_brewing);

    my $msg = $max_beer_brewing->{warnings}[0];
    like($msg, qr{doesn't have}i, 'should say what is wrong');
    like($msg, qr{\bwhatever\b}, 'should mention the tag');
}


sub rejects_array_for_tags_page_index : Tests {
    eval {
        Comic::Out::Tags->new(index => []);
    };
    like($@, qr{\bindex\b}, 'should mention the setting');
    like($@, qr{\barray\b}, 'should say what is wrong');
}


sub accepts_one_tags_page_index_template_for_all_languages : Tests {
    my $tags = Comic::Out::Tags->new(template => 'page.templ', index => 'index.templ');
    is($tags->_get_index_template('English'), 'index.templ');
    is($tags->_get_index_template('Deutsch'), 'index.templ');
    is($tags->_get_index_template('whatever, really'), 'index.templ');
}


sub accetps_per_language_tags_page_index_templates : Tests {
    my $tags = Comic::Out::Tags->new(template => { 'English' => 'index.templ' });
    is($tags->_get_tag_page_template('English'), 'index.templ');
    eval {
        $tags->_get_index_template('unknown language');
    };
    like($@, qr{index}i, 'should say what is wrong');
    like($@, qr{unknown language}, 'should mention the language');
}


sub rejects_index_template_without_tag_pages_template : Tests {
    eval {
        Comic::Out::Tags->new(index => 'index.templ');
    };
    like($@, qr{\bComic::Out::Tag.template\b});
}


sub writes_index_tags_page_for_list : Tests {
    MockComic::fake_file('page.templ', '...');
    my $index = << 'TEMPL';
        [% FOREACH c IN tags_page.$Language %]
            plain link: [% c.key %] -> [% root %][% c.value %] ([% tag_count.$Language.${c.key} %])
        [% END %]
TEMPL
    MockComic::fake_file('index.templ', $index);

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['brewing'],
        },
    );

    my $tags = Comic::Out::Tags->new(template => 'page.templ', index => 'index.templ');
    $tags->generate($comic);
    $tags->generate_all($comic);

    MockComic::assert_wrote_file('generated/web/english/tags/index.html',
        qr{plain link: brewing -> \.\./tags/brewing\.html \(1\)}m);
}


sub writes_index_tags_page_for_cloud : Tests {
    MockComic::fake_file('page.templ', '...');
    my $index = << 'TEMPL';
        [% FOREACH t IN tags_page.$Language %]
            size: [% tag_rank.$Language.${t.key} %] for [% t.key %] -> [% root %][% t.value %]
        [% END %]
TEMPL
    MockComic::fake_file('index.templ', $index);
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['brewing'],
        },
    );
    $comic->{modified} = '2023-01-01';

    my $tags = Comic::Out::Tags->new(template => 'page.templ', index => 'index.templ');
    $tags->generate($comic);
    $tags->generate_all($comic);

    MockComic::assert_wrote_file('generated/web/english/tags/index.html',
        qr{size: taglevel5 for brewing -> ../tags/brewing.html}m);
}


sub last_modified_date_in_tags_index_is_latest_tagged_comic_modification : Tests {
    MockComic::fake_file('page.templ', '...');
    MockComic::fake_file('index.templ', '[% last_modified %]');
    my @comics;
    foreach my $date (qw(2023-01-01 2023-02-02 2023-03-03 2023-02-22)) {
       my $comic = MockComic::make_comic(
            $MockComic::TITLE => {
                $MockComic::ENGLISH => "beer on $date",
            },
            $MockComic::TAGS => {
                $MockComic::ENGLISH => [ $date ],
            },
        );
        $comic->{modified} = $date;
        push @comics, $comic;
    }

    my $tags = Comic::Out::Tags->new(template => 'page.templ', index => 'index.templ');
    foreach my $comic (@comics) {
        $tags->generate($comic);
    }
    $tags->generate_all(@comics);

    MockComic::assert_wrote_file('generated/web/english/tags/index.html', '2023-03-03');
}


sub reserves_index_html_for_index_page : Tests {
    MockComic::fake_file('page.templ', 'page');
    MockComic::fake_file('index.templ', 'index');

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['index'],
        },
    );

    my $tags = Comic::Out::Tags->new(template => 'page.templ', index => 'index.templ');
    $tags->generate($comic);
    $tags->generate_all($comic);

    MockComic::assert_wrote_file('generated/web/english/tags/index.html', 'index');
    MockComic::assert_wrote_file('generated/web/english/tags/index_0.html', 'page');
}
