use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::DuplicatedTexts;


__PACKAGE__->runtests() unless caller;

my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::DuplicatedTexts->new();
}


sub duplicated_text_in_other_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => [' Paul shows Max his bym.'],
            $MockComic::ENGLISH => ['Paul shows Max his bym. '],
    });

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{duplicated text}i, 'wrong error message');
    like(${$comic->{warnings}}[0], qr{'Paul shows Max his bym\.'}, 'should mention duplicated text');
    like(${$comic->{warnings}}[0], qr{Deutsch}, 'should mention offending languages');
    like(${$comic->{warnings}}[0], qr{English}, 'should mention offending languages');
}


sub duplicated_text_in_other_language_ignores_text_order : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['a', 'b', 'c'],
            $MockComic::ENGLISH => ['z', 'x', 'a'],
        },
        $MockComic::FRAMES => [0, 0, 100, 100],
    );

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{duplicated text}i);
}


sub duplicated_text_in_other_language_ignores_names : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['Max:', 'guck mal', ' Paul:', 'was?'],
            $MockComic::ENGLISH => ['Max:', 'look at this', 'Paul: ', 'what?'],
        },
        $MockComic::FRAMES => [0, 0, 100, 100],
    );

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}


sub allowed_duplicated_words : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['blah'],
            $MockComic::ENGLISH => ['blah'],
        },
        $MockComic::JSON => '"allow-duplicated": ["blah"]',
    );

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}


sub duplicated_word_parts : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['blahblah'],
            $MockComic::ENGLISH => ['blahblah'],
        },
        $MockComic::JSON => '"allow-duplicated": ["blah"]',
    );

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{duplicated text}i);
}


sub duplicated_in_container_layers : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="ContainerDeutsch">
        <g inkscape:groupmode="layer" id="layer20" inkscape:label="Deutsch">
            <text>oops</text>
        </g>
    </g>
    <g inkscape:groupmode="layer" id="layer19" inkscape:label="ContainerEnglish">
        <g inkscape:groupmode="layer" id="layer21" inkscape:label="English">
            <text>oops</text>
        </g>
    </g>
XML

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{duplicated text}i);
}


sub duplicated_multiline : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="Deutsch">
        <text x="1" y="1">
            <tspan>take</tspan>
            <tspan>that</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" id="layer21" inkscape:label="English">
        <text x="1" y="1">
            <tspan>take</tspan>
            <tspan>that</tspan>
        </text>
    </g>
XML

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{duplicated text}i);
}


sub duplicated_allowed_multiline_space_separated : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML,
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="Deutsch">
        <text x="1" y="1">
            <tspan>take</tspan>
            <tspan>that</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" id="layer21" inkscape:label="English">
        <text x="1" y="1">
            <tspan>take</tspan>
            <tspan>that</tspan>
        </text>
    </g>
XML
    $MockComic::JSON => '"allow-duplicated": ["take that"]');

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}


sub duplicated_allowed_multiline_newline_separated : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML,
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="Deutsch">
        <text x="1" y="1">
            <tspan>take</tspan>
            <tspan>that</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" id="layer21" inkscape:label="English">
        <text x="1" y="1">
            <tspan>take</tspan>
            <tspan>that</tspan>
        </text>
    </g>
XML
    $MockComic::JSON => '"allow-duplicated": ["take\nthat"]');

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}
