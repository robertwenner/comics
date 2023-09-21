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
    is($tags->_get_template('English'), 'tagcloud.templ');
    is($tags->_get_template('Deutsch'), 'tagcloud.templ');
    is($tags->_get_template('whatever, really'), 'tagcloud.templ');
}


sub configure_template_per_language : Tests {
    MockComic::fake_file('tagcloud.en', 'template goes here');
    my $tags = Comic::Out::Tags->new(template => { 'English' => 'tagcloud.en' });
    is($tags->_get_template('English'), 'tagcloud.en');
    eval {
        $tags->_get_template('unknown language');
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
        <h1>[% tag %]</h1>
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

    $tags->generate($comic);
    $tags->_write_tags_pages($comic);

    MockComic::assert_made_some_dirs('generated/web/deutsch/tags', 'generated/web/english/tags');
    MockComic::assert_wrote_file('generated/web/deutsch/tags/brauen.html',
        qr{<h1>brauen</h1>}m);
    MockComic::assert_wrote_file('generated/web/deutsch/tags/brauen.html',
        qr{<a href="comics/bier\.html">Bier</a>}m);

    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html',
        qr{<h1>brewing</h1>}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html',
        qr{<a href="comics/beer\.html">beer</a>}m);
}


sub defines_tags_page_template_variables : Tests {
    my $content = << 'TEMPL';
        url: [% url %]
        language: [% language %]
        root: [% root %]
TEMPL
    MockComic::fake_file('tags.templ', $content);
    my $tags = Comic::Out::Tags->new(template => 'tags.templ', outdir => 'tags');

    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->_write_tags_pages($max_beer_brewing, $max_paul_beer_brewing);

    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{url: /tags/brewing.html}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{language: english}m);
    MockComic::assert_wrote_file('generated/web/english/tags/brewing.html', qr{root: \.\./}m);
}


sub adds_tag_page_links_to_comic : Tests {
    MockComic::fake_file('tags.templ', '');
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
    MockComic::fake_file('tags.templ', '');
    my $tags = Comic::Out::Tags->new(template => 'tags.templ', outdir => 'tags');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'beer',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['*&lt;hops/malt&gt;...: &amp; so on , right!?'],
        },
    );

    $tags->generate($comic);
    $tags->_write_tags_pages($comic);

    MockComic::assert_wrote_file('generated/web/deutsch/tags/hopsmaltsoonright.html');
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
    MockComic::fake_file('tags.templ', '...');

    my $tags = Comic::Out::Tags->new('min-count' => '3', 'template' => 'tags.templ');
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->_put_tags_in_comics($max_beer_brewing, $max_paul_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {});
    is_deeply($max_paul_beer_brewing->{tags}{'Deutsch'}, {});
    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is_deeply($max_paul_beer_brewing->{tags}{'English'}, {});
}
