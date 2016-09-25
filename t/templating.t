use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file("templates/deutsch/sitemap-xml.templ", "...");
}


sub make_comic {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::DEUTSCH => 'Ein lustiges Comic.',
        },
        $MockComic::TAGS => {
            $MockComic::DEUTSCH => ['Bier', 'Craft'],
        },
    );
    return $comic;
}


sub simple_expression : Test {
    MockComic::fake_file("file.templ", "[% modified %]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("modified" => "today")), "today");
}


sub case_sensitive : Test {
    MockComic::fake_file('file.templ', "[% modified %]");
    eval {
        Comic::_templatize('comic.svg', 'file.templ', ("MODified" => "today"));
    };
    like($@, qr/undefined variable/i);
}


sub white_space : Test {
    MockComic::fake_file("file.templ", "[%modified\t\t %]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("modified" => "today")), "today");
}


sub utf8 : Test {
    MockComic::fake_file("file.templ", "[%modified\t\t %]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("modified" => "töday")), "töday");
}


sub template_syntax_error : Test {
    MockComic::fake_file("file.templ", "[% modified ");
    eval {
        Comic::_templatize('comic.svg', 'file.templ', ("modified" => "today"));
    };
    like($@, qr/Unresolved template marker/i);
}


sub unknown_variable : Test {
    MockComic::fake_file("file.templ", "[% modified %]");
    eval {
        Comic::_templatize('comic.svg', 'file.templ', ("a" => "b"));
    };
    like($@, qr/undefined variable/i);
}


sub stray_opening_tag : Test {
    MockComic::fake_file("file.templ", "[% a");
    eval {
        Comic::_templatize('comic.svg', 'file.templ', ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub stray_closing_tag : Test {
    MockComic::fake_file("file.templ", "\nblah\na %]\nblah\n\n");
    eval {
        Comic::_templatize('comic.svg', 'file.templ', ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub array : Test {
    MockComic::fake_file("file.templ", "[% FOREACH a IN array %][% a %][% END %]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("array" => ["a", "b", "c"])),
        "abc");
}


sub hash_one_element : Test {
    MockComic::fake_file('file.templ', "[% hash.key %]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("hash" => {"key" => "the key"})),
        "the key");
}


sub hash_all_elements : Tests {
    MockComic::fake_file("file.templ", '[% FOREACH o IN order %][% hash.$o %][% END %]');
    my %hash = ("a" => "1", "b" => "2", "c" => "3");
    my @order = sort keys %hash;
    my %vars = ("hash" => \%hash, "order" => \@order);
    is(Comic::_templatize('comic.svg', 'file.templ', %vars),
        '123');
}


sub hash_of_hashes: Test {
    my %languages = (
        "de" => { "1" => "eins", "2" => "zwei" },
        "en" => { "1" => "one", "2" => "two" },
    );
    my @lang_order = qw(de en);
    my @in_lang_order = qw(1 2);

    MockComic::fake_file('file.templ', <<'TEMPL');
[% FOREACH l IN langorder %]
    [% FOREACH il IN in_lang_order %]
        [% FOREACH v IN languages.$l.$il %]
            [% v %]
        [% END %]
    [% END %]
[% END %]
TEMPL

    like(Comic::_templatize('comic.svg', 'file.templ', (
            "languages" => \%languages,
            "langorder" => \@lang_order,
            "in_lang_order" => \@in_lang_order)),
        qr{^\s*eins\s*zwei\s*one\s*two\s*$}m);
}


sub function : Test {
    MockComic::fake_file('file.templ', '[% func %]');
    is(Comic::_templatize('comic.svg', 'file.templ', ("func" => &{ return "works" })),
        "works");
}


sub object_member : Tests {
    my $comic = make_comic();
    is($comic->{srcFile}, "some_comic.svg");
    MockComic::fake_file('file.templ', "[%comic.srcFile%]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("comic" => $comic)),
        "some_comic.svg");
    MockComic::fake_file('file.templ', "[%comic.meta_data.title.Deutsch%]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("comic" => $comic)),
        "Bier trinken");
}


sub object_function_code_ref : Tests {
    my $comic = make_comic();
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Pimperanto')%]");
    is(Comic::_templatize('comic.svg', 'file.templ', (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        1);
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Deutsch')%]");
    is(Comic::_templatize('comic.svg', 'file.templ', (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        0);
}


sub object_function_wrapped : Tests {
    my $comic = make_comic();
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Pimperanto')%]");
    is(Comic::_templatize('comic.svg', 'file.templ', (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        1);
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Deutsch')%]");
    is(Comic::_templatize('comic.svg', 'file.templ', (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        0);

    MockComic::fake_file('file.templ', "[%notFor('Pimperanto')%]");
    is(Comic::_templatize('comic.svg', 'file.templ',
        ("notFor" => sub { return $comic->_not_for(@_);})),
        1);
    MockComic::fake_file('file.templ', "[%notFor('Deutsch')%]");
    is(Comic::_templatize('comic.svg', 'file.templ',
        ("notFor" => sub { return $comic->_not_for(@_);})),
        0);
}


sub from_comic : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken',
        },
        $MockComic::DESCRIPTION => {
            $MockComic::DEUTSCH => 'Ein lustiges Comic.',
        },
        $MockComic::PUBLISHED_WHEN => '2016-08-20',
        $MockComic::WHO => {
            $MockComic::DEUTSCH => [ "Max", "Paul" ],
        },
        $MockComic::TAGS => {
            $MockComic::DEUTSCH => [ "Bier", "Saufen", "Craft" ],
        },
    );

    MockComic::fake_file('templates/deutsch/sitemap-xml.templ', '...');
    MockComic::fake_file('templates/deutsch/comic-page.templ', <<'TEMPLATE');
Biercomics: [% title %]
last-modified: [% modified %]
description: [% description %]
[% title %]
[% png_file %] [% height %] by [% width %]
[% transcriptJson %]
[% transcriptHtml %]
[% url %]
[% FOREACH w IN who %]
[% w %].
[% END %]
Image: [% image %]
Copyright year: [% year %]
Keywords: [% keywords %]
TEMPLATE
    Comic::export_all_html({
        'Deutsch' => 'templates/deutsch/comic-page.templ',
    },
    {
        'Deutsch' => 'templates/deutsch/sitemap-xml.templ',
    },
    {
        'Deutsch' => 'generated/deutsch/web/sitemap.xml',
    });

    my $wrote = $comic->_do_export_html("Deutsch", 'templates/deutsch/comic-page.templ');
    like($wrote, qr/Bier trinken/m, "title");
    like($wrote, qr/1970-01-01/m, "last modified");
    like($wrote, qr/bier-trinken\.png/m, "png file name");
    like($wrote, qr/200 by 600/m, "dimensions");
    like($wrote, qr{https://biercomics.de/comics/bier-trinken.html}m, "url");
    like($wrote, qr{Max\.\s*Paul\.}m, "who");
    like($wrote, qr{Image: https://biercomics.de/comics/bier-trinken.png}m, "image");
    like($wrote, qr{Copyright year: 2016}m, "copyright year");
    like($wrote, qr{Keywords: Bier,Saufen,Craft}m, "keywords");
}


sub html_special_as_is : Test {
    MockComic::fake_file('file.templ', "[%modified\t\t %]");
    is(Comic::_templatize('comic.svg', 'file.templ', ("modified" => "<b>")), "<b>");
}


sub error_includes_template_file_name : Tests {
    MockComic::fake_file('file.templ', "[% oops %]");
    eval {
        Comic::_templatize('comic.svg', 'file.templ');
    };
    like($@, qr{\bfile.templ\b});
    like($@, qr{\bcomic.svg\b});
    like($@, qr{undefined variable});
}


sub catches_perl_array : Tests {
    MockComic::fake_file('file.templ', '[% x %]');
    eval {
        Comic::_templatize('comic.svg', 'file.templ', ("x" => [1, 2, 3]));
    };
    like($@, qr/ARRAY/i);
}


sub catches_perl_hash : Tests {
    MockComic::fake_file('file.templ', '[% x %]');
    eval {
        Comic::_templatize('comic.svg', 'file.templ', ("x" => {a =>1, b => 2}));
    };
    like($@, qr/HASH/i);
}


sub sparse_collection_top_n : Tests {
    MockComic::fake_file("file.templ", <<'TEMPL');
[% done = 0 %]
[% FOREACH a IN array %]
[% NEXT IF a % 2 == 0 %]
[% LAST IF done == max %]
[% done = done + 1 %]
[% a %]
[% END %]
TEMPL
    like(Comic::_templatize('comic.svg', 'file.templ', ("array" => [1 .. 10], 'max' => 3)),
        qr{^\s*1\s+3\s+5\s*$});
}
