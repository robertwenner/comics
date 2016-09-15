use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file("web/deutsch/sitemap-xml.templ", "...");
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
    is(Comic::_templatize('comic.svg', 'file.templ', '[% modified %]', ("modified" => "today")), "today");
}


sub case_sensitive : Test {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', '[% modified %]', ("MODified" => "today"));
    };
    like($@, qr/undefined variable/i);
}


sub white_space : Test {
    is(Comic::_templatize('comic.svg', 'file.templ', "[%modified\t\t %]", ("modified" => "today")), "today");
}


sub utf8 : Test {
    is(Comic::_templatize('comic.svg', 'file.templ', '[%modified%]', ("modified" => "töday")), "töday");
}


sub template_syntax_error : Test {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', '[% modified ', ("modified" => "today"));
    };
    like($@, qr/Unresolved template marker/i);
}


sub unknown_variable : Test {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', '[% modified %]', ("a" => "b"));
    };
    like($@, qr/undefined variable/i);
}


sub stray_opening_tag : Test {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', '[% a', ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub stray_closing_tag : Test {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', "\nblah\na %]\nblah\n\n", ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub array : Test {
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[% FOREACH a IN array %][% a %][% END %]", ("array" => ["a", "b", "c"])),
        "abc");
}


sub hash_one_element : Test {
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[% hash.key %]", ("hash" => {"key" => "the key"})),
        "the key");
}


sub hash_all_elements : Tests {
    my %hash = ("a" => "1", "b" => "2", "c" => "3");
    my @order = sort keys %hash;
    my %vars = ("hash" => \%hash, "order" => \@order);
    is(Comic::_templatize('comic.svg', 'file.templ', '[% FOREACH o IN order %][% hash.$o %][% END %]', %vars),
        '123');
}


sub hash_of_hashes: Test {
    my %languages = (
        "de" => { "1" => "eins", "2" => "zwei" },
        "en" => { "1" => "one", "2" => "two" },
    );
    my @lang_order = qw(de en);
    my @in_lang_order = qw(1 2);

    my $template = <<'TEMPL';
[% FOREACH l IN langorder %]
    [% FOREACH il IN in_lang_order %]
        [% FOREACH v IN languages.$l.$il %]
            [% v %]
        [% END %]
    [% END %]
[% END %]
TEMPL

    like(Comic::_templatize('comic.svg', 'file.templ', $template, (
            "languages" => \%languages,
            "langorder" => \@lang_order,
            "in_lang_order" => \@in_lang_order)),
        qr{^\s*eins\s*zwei\s*one\s*two\s*$}m);
}


sub function : Test {
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[% func %]", ("func" => &{ return "works" })),
        "works");
}


sub object_member : Tests {
    my $comic = make_comic();
    is($comic->{file}, "some_comic.svg");
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%comic.file%]", ("comic" => $comic)),
        "some_comic.svg");
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%comic.meta_data.title.Deutsch%]", ("comic" => $comic)),
        "Bier trinken");
}


sub object_function_code_ref : Tests {
    my $comic = make_comic();
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%notFor(comic, 'Pimperanto')%]", (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        1);
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%notFor(comic, 'Deutsch')%]", (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        0);
}


sub object_function_wrapped : Tests {
    my $comic = make_comic();
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%notFor(comic, 'Pimperanto')%]", (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        1);
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%notFor(comic, 'Deutsch')%]", (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        0);

    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%notFor('Pimperanto')%]", ("notFor" => sub { return $comic->_not_for(@_);})),
        1);
    is(Comic::_templatize('comic.svg', 'file.templ',
        "[%notFor('Deutsch')%]", ("notFor" => sub { return $comic->_not_for(@_);})),
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
 
    MockComic::fake_file('web/deutsch/comic-page.templ', <<'TEMPLATE');
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
    $comic->export_all_html();
    my $wrote = $comic->_do_export_html("Deutsch");
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
    is(Comic::_templatize('comic.svg', 'file.templ', "[%modified\t\t %]", ("modified" => "<b>")), "<b>");
}


sub error_includes_template_file_name : Tests {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', "[% oops %]");
    };
    like($@, qr{\bfile.templ\b});
    like($@, qr{\bcomic.svg\b});
    like($@, qr{undefined variable});
}


sub catches_perl_array : Tests {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', '[% x %] ', ("x" => [1, 2, 3]));
    };
    like($@, qr/ARRAY/i);
}


sub catches_perl_hash : Tests {
    eval {
        Comic::_templatize('comic.svg', 'file.templ', '[% x %] ', ("x" => {a =>1, b => 2}));
    };
    like($@, qr/HASH/i);
}
