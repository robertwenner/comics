use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Out::Template;
use Comic::Out::HtmlComicPage;


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


sub simple_expression : Tests {
    MockComic::fake_file("file.templ", "[% modified %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("modified" => "today")), "today");
}


sub case_sensitive : Tests {
    MockComic::fake_file('file.templ', "[% modified %]");
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("MODified" => "today"));
    };
    like($@, qr/undefined variable/i);
}


sub white_space : Tests {
    MockComic::fake_file("file.templ", "[%modified\t\t %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("modified" => "today")), "today");
}


sub utf8 : Tests {
    MockComic::fake_file("file.templ", "[%modified\t\t %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("modified" => "töday")), "töday");
}


sub filter_html_special_in_variable : Tests {
    MockComic::fake_file("file.templ", "[% FILTER html %][%var%][% END %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("var" => "<>")), "&lt;&gt;");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("var" => "ü")), "ü");
}


sub filter_html_special_in_markup : Tests {
    MockComic::fake_file("file.templ", "[% FILTER html %]<[%var%]>[% END %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("var" => "&")), "&lt;&amp;&gt;");
}


sub template_syntax_error : Tests {
    MockComic::fake_file("file.templ", "[% modified ");
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("modified" => "today"));
    };
    like($@, qr/Unresolved template marker/i);
}


sub unknown_variable : Tests {
    MockComic::fake_file("file.templ", "[% modified %]");
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("a" => "b"));
    };
    like($@, qr/undefined variable/i);
}


sub stray_opening_tag : Tests {
    MockComic::fake_file("file.templ", "[% a");
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub stray_closing_tag : Tests {
    MockComic::fake_file("file.templ", "\nblah\na %]\nblah\n\n");
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub array : Tests {
    MockComic::fake_file("file.templ", "[% FOREACH a IN array %][% a %][% END %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("array" => ["a", "b", "c"])),
        "abc");
}


sub array_with_separators : Tests {
    MockComic::fake_file("file.templ", "[% FOREACH a IN array %][% a %][% IF !loop.last() %],[% END %][% END %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("array" => ["a", "b", "c"])),
        "a,b,c");
}


sub hash_hard_coded_key : Tests {
    MockComic::fake_file('file.templ', "[% hash.key %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("hash" => {"key" => "the key"})),
        "the key");
}


sub simple_hash : Tests {
    MockComic::fake_file("file.templ", '[% FOREACH h IN hash %][% h.key %] => [% h.value %][% END %]');
    my %hash = ("a" => "1");
    my %vars;
    $vars{'hash'} = \%hash;
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', %vars),
        'a => 1');
}


sub hash_all_elements_with_order : Tests {
    MockComic::fake_file("file.templ", '[% FOREACH o IN order %][% hash.$o %][% END %]');
    my %hash = ("a" => "1", "b" => "2", "c" => "3");
    my @order = sort keys %hash;
    my %vars = ("hash" => \%hash, "order" => \@order);
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', %vars),
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

    like(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', (
            "languages" => \%languages,
            "langorder" => \@lang_order,
            "in_lang_order" => \@in_lang_order)),
        qr{^\s*eins\s*zwei\s*one\s*two\s*$}m);
}


sub function: Tests {
    MockComic::fake_file('file.templ', '[% func %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("func" => &{ return "works" })),
        "works");
}


sub object_member : Tests {
    my $comic = make_comic();
    is($comic->{srcFile}, "some_comic.svg");
    MockComic::fake_file('file.templ', "[%comic.srcFile%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("comic" => $comic)),
        "some_comic.svg");
    MockComic::fake_file('file.templ', "[%comic.meta_data.title.Deutsch%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("comic" => $comic)),
        "Bier trinken");
}


sub object_function_code_ref : Tests {
    my $comic = make_comic();
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Pimperanto')%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', (
            "notFor" => \&Comic::not_for,
            "comic" => $comic,
        )),
        1);
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Deutsch')%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', (
            "notFor" => \&Comic::not_for,
            "comic" => $comic,
        )),
        0);
}


sub object_function_wrapped : Tests {
    my $comic = make_comic();
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Pimperanto')%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', (
            "notFor" => sub { return Comic::not_for(@_); },
            "comic" => $comic,
        )),
        1);
    MockComic::fake_file('file.templ', "[%notFor(comic, 'Deutsch')%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', (
            "notFor" => sub { return Comic::not_for(@_); },
            "comic" => $comic,
        )),
        0);

    MockComic::fake_file('file.templ', "[%notFor('Pimperanto')%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '',
        ("notFor" => sub { return $comic->not_for(@_);})),
        1);
    MockComic::fake_file('file.templ', "[%notFor('Deutsch')%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '',
        ("notFor" => sub { return $comic->not_for(@_);})),
        0);
}


sub object_function_public : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken',
        },
        $MockComic::PUBLISHED_WHEN => '2099-01-01',
    );
    # Cannot call a private function (starting with an underscore), that always
    # gets a var.undef error.
    MockComic::fake_file('file.templ', "[%IF comic.not_yet_published()%]not yet[%END%]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', (
            "comic" => $comic,
        )),
        'not yet');
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
        $MockComic::MTIME => DateTime->new(
            year => 2016, month => 1, day => 1, time_zone => '-05:00')->epoch,
    );

    MockComic::fake_file('templates/deutsch/sitemap-xml.templ', '...');
    MockComic::fake_file('templates/deutsch/comic-page.templ', <<'TEMPLATE');
Biercomics: [% comic.meta_data.title.$Language %]
last-modified: [% comic.modified %]
description: [% FILTER html %][% comic.meta_data.description.$Language %][% END %]
[% comic.meta_data.title.$Language %]
[% comic.pngFile.$Language %] [% comic.height %] by [% comic.width %]
[% comic.url.$Language %]
who: [% USE JSON %][% comic.meta_data.who.$Language.join(',') %]
Image: [% comic.imageUrl.$Language %]
Copyright year: [% year %]
Keywords: [% comic.meta_data.tags.$Language.join(',') %]
Transript: [% comic.transcript.$Language.join(' ') %]
TEMPLATE
    my $hcp = Comic::Out::HtmlComicPage->new({
        'HtmlComicPage' => {
            'outdir' => 'generated/',
            'Templates' => {
                'Deutsch' => 'templates/deutsch/comic-page.templ',
            },
        },
    });
    $hcp->generate_all(($comic));
    my $wrote = $hcp->_do_export_html($comic, "Deutsch", 'templates/deutsch/comic-page.templ');
    like($wrote, qr/Bier trinken/m, "title");
    like($wrote, qr/2016-01-01/m, "last modified");
    like($wrote, qr/bier-trinken\.png/m, "png file name");
    like($wrote, qr/200 by 600/m, "dimensions");
    like($wrote, qr{https://biercomics.de/comics/bier-trinken.html}m, "url");
    like($wrote, qr{who: Max,Paul}m, "who");
    like($wrote, qr{Image: https://biercomics.de/comics/bier-trinken.png}m, "image URL");
    like($wrote, qr{Copyright year: 2016}m, "copyright year");
    like($wrote, qr{Keywords: Bier,Saufen,Craft}m, "tags");
}


sub html_special_as_is: Tests {
    MockComic::fake_file('file.templ', "[%modified\t\t %]");
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("modified" => "<b>")), "<b>");
}


sub error_includes_template_file_name : Tests {
    MockComic::fake_file('file.templ', "[% oops %]");
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '');
    };
    like($@, qr{\bfile.templ\b});
    like($@, qr{\bcomic.svg\b});
    like($@, qr{undefined variable});
}


sub catches_perl_array : Tests {
    MockComic::fake_file('file.templ', '[% x %]');
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("x" => [1, 2, 3]));
    };
    like($@, qr/ARRAY/i);
}


sub catches_perl_hash : Tests {
    MockComic::fake_file('file.templ', '[% x %]');
    eval {
        Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("x" => {a =>1, b => 2}));
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
    like(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ("array" => [1 .. 10], 'max' => 3)),
        qr{^\s*1\s+3\s+5\s*$});
}


sub consts_in_templates : Tests {
    MockComic::fake_file('file.templ', '[% const.name = "foo" %][% const.name %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ()), "foo");
}


sub in_string : Tests {
    MockComic::fake_file('file.templ', '[% const.name = "foo" %][% "${const.name}" %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', '', ()), "foo");
}


sub sets_language : Tests {
    MockComic::fake_file('file.templ', '[% "some/$language/path" %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ()), "some/deutsch/path");
}


sub variable_case : Tests {
    MockComic::fake_file('file.templ', '[% a %][% A %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ('a' => 'a', 'A' => 'A')), "aA");
}


sub replace_filter : Tests {
    MockComic::fake_file('file.templ', '[% FILTER replace("a", "A") %][% a %][% END %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ('a' => 'a')), "A");
}


sub dquote : Tests {
    MockComic::fake_file('file.templ', '[% a.dquote %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ('a' => 'so, "what"?')), 'so, \"what\"?');
}


sub joined : Tests {
    MockComic::fake_file('file.templ', '[% a.join(",") %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ('a' => [1, 2, 3])), '1,2,3');
}


sub json : Tests {
    MockComic::fake_file('file.templ', '[% USE JSON %][% a.json %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ('a' => '"x"')), '"\"x\""');
    MockComic::fake_file('file.templ', '[% USE JSON %][% a.json %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ('a' => [])), '[]');
    MockComic::fake_file('file.templ', '[% USE JSON %][% a.json %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ('a' => ['x','"'])), '["x","\""]');
}


sub default : Tests {
    MockComic::fake_file('file.templ', '[% DEFAULT a = "default" %][% a %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ()), 'default');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', (a => 'set')), 'set');
}


sub check_defined_scalar : Tests {
    MockComic::fake_file('file.templ', '[% DEFAULT a = "" %][% IF a %][% a %][% END %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', ()), '');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', (a => 'set')), 'set');
}


sub check_array_empty : Tests {
    MockComic::fake_file('file.templ', '[% IF a %][% a.join(",") %][% END %]');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', (a => [])), '');
    is(Comic::Out::Template::templatize('comic.svg', 'file.templ', 'Deutsch', (a => ['set'])), 'set');
}
