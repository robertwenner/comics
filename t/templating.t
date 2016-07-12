use strict;
use warnings;
no warnings qw/redefine/;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub make_comic {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Bier trinken',
        },
    );
    $comic->{height} = 200;
    $comic->{width} = 600;
    return $comic;
}


sub simple_expression : Test {
    is(Comic::_templatize('[% modified %]', ("modified" => "today")), "today");
}


sub case_sensitive : Test {
    eval {
        Comic::_templatize('[% modified %]', ("MODified" => "today"));
    };
    like($@, qr/undefined variable/i);
}


sub white_space : Test {
    is(Comic::_templatize("[%modified\t\t %]", ("modified" => "today")), "today");
}


sub utf8 : Test {
    is(Comic::_templatize('[%modified%]', ("modified" => "töday")), "töday");
}


sub template_syntax_error : Test {
    eval {
        Comic::_templatize('[% modified ', ("modified" => "today"));
    };
    like($@, qr/Unresolved template marker/i);
}


sub unknown_variable : Test {
    eval {
        Comic::_templatize('[% modified %]', ("a" => "b"));
    };
    like($@, qr/undefined variable/i);
}


sub stray_opening_tag : Test {
    eval {
        Comic::_templatize('[% a', ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub stray_closing_tag : Test {
    eval {
        Comic::_templatize("\nblah\na %]\nblah\n\n", ("a" => "b"));
    };
    like($@, qr/unresolved template marker/i);
}


sub array : Test {
    is(Comic::_templatize(
        "[% FOREACH a IN array %][% a %][% END %]", ("array" => ["a", "b", "c"])),
        "abc");
}


sub hash : Test {
    is(Comic::_templatize(
        "[% hash.key %]", ("hash" => {"key" => "the key"})),
        "the key");
}


sub function : Test {
    is(Comic::_templatize(
        "[% func %]", ("func" => &{ return "works" })),
        "works");
}


sub object_member : Tests {
    my $comic = make_comic();
    is($comic->{file}, "some_comic.svg");
    is(Comic::_templatize(
        "[%comic.file%]", ("comic" => $comic)),
        "some_comic.svg");
    is(Comic::_templatize(
        "[%comic.meta_data.title.Deutsch%]", ("comic" => $comic)),
        "Bier trinken");
}


sub object_function_code_ref : Tests {
    my $comic = make_comic();
    is(Comic::_templatize(
        "[%notFor(comic, 'Pimperanto')%]", (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        1);
    is(Comic::_templatize(
        "[%notFor(comic, 'Deutsch')%]", (
            "notFor" => \&Comic::_not_for,
            "comic" => $comic,
        )),
        0);
}


sub object_function_wrapped : Tests {
    my $comic = make_comic();
    is(Comic::_templatize(
        "[%notFor(comic, 'Pimperanto')%]", (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        1);
    is(Comic::_templatize(
        "[%notFor(comic, 'Deutsch')%]", (
            "notFor" => sub { return Comic::_not_for(@_); },
            "comic" => $comic,
        )),
        0);

    is(Comic::_templatize(
        "[%notFor('Pimperanto')%]", ("notFor" => sub { return $comic->_not_for(@_);})),
        1);
    is(Comic::_templatize(
        "[%notFor('Deutsch')%]", ("notFor" => sub { return $comic->_not_for(@_);})),
        0);
}


sub from_comic : Tests {
    my $comic = make_comic();
    MockComic::fake_file('web/deutsch/comic-page.templ', <<'TEMPLATE');
Biercomics: [% title %]
last-modified: [% modified %]
description: [% description %]
[% title %]
[% png_file %] [% height %] by [% width %]
[% transcript %]
[% url %]
TEMPLATE
    my $wrote = $comic->_do_export_html("Deutsch");
    like($wrote, qr/Bier trinken/m);
    like($wrote, qr/1970-01-01/m);
    like($wrote, qr/bier-trinken\.png/m);
    like($wrote, qr/200 by 600/m);
    like($wrote, qr{https://biercomics.de/comics/bier-trinken.html}m);
}


sub html_special_as_is : Test {
    is(Comic::_templatize("[%modified\t\t %]", ("modified" => "<b>")), "<b>");
}
