use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub empty_text_found : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => ['']});
    eval {
        $comic->_check_empty_texts($MockComic::DEUTSCH);
    };
    like($@, qr{Empty text in Deutsch}i);
}


sub whitespace_only_text_found : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => [' ']});
    eval {
        $comic->_check_empty_texts($MockComic::DEUTSCH);
    };
    like($@, qr{Empty text in Deutsch}i);
}


sub empty_text_other_language_ignored : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => ['']});
    eval {
        $comic->_check_empty_texts("English");
    };
    is($@, '');
}


sub duplicated_text_in_other_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => [' Paul shows Max his bym.'],
            $MockComic::ENGLISH => ['Paul shows Max his bym. '],
    });
    eval {
        $comic->_check_transcript("English");
    };
    like($@, qr{^some_comic.svg}, 'should include file name');
    like($@, qr{duplicated text}, 'wrong error message');
    like($@, qr{'Paul shows Max his bym\.'}, 'should mention duplicated text');
    like($@, qr{English and Deutsch}, 'should mention offending languages');
}


sub duplicated_text_in_other_language_ignores_text_order : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['a', 'b', 'c'],
            $MockComic::ENGLISH => ['z', 'x', 'a'],
    });
    eval {
        $comic->_check_transcript("English");
    };
    like($@, qr{duplicated text});
}


sub duplicated_text_in_other_language_ignores_names : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['Max:', 'guck mal', ' Paul:', 'was?'],
            $MockComic::ENGLISH => ['Max:', 'look at this', 'Paul: ', 'what?'],
        });
    eval {
        $comic->_check_transcript("English");
    };
    is($@, '');
}


sub duplicated_text_in_other_language_trailing_colon_no_speaker : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['Paul:', 'bla', 'The microphone comes to live:'],
            $MockComic::ENGLISH => ['Paul:', 'blah', 'The microphone comes to live:'],
    });
    eval {
        $comic->_check_transcript("English");
    };
    like($@, qr{duplicated text});
}


sub last_text_is_speaker_indicator : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['Max:', 'blah', 'Paul:'],
    });
    eval {
        $comic->_check_transcript("Deutsch");
    };
    like($@, qr{speaker's text missing after 'Paul:'});
}


sub allowed_duplicated_words : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['blah'],
            $MockComic::ENGLISH => ['blah'],
        },
        $MockComic::JSON => '"allow-duplicated": ["blah"]',
    );
    eval {
        $comic->_check_transcript("English");
    };
    is($@, '');
}


sub duplicated_word_parts : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            $MockComic::DEUTSCH => ['blahblah'],
            $MockComic::ENGLISH => ['blahblah'],
        },
        $MockComic::JSON => '"allow-duplicated": ["blah"]',
    );
    eval {
        $comic->_check_transcript("English");
    };
    like($@, qr{duplicated text});
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
    eval {
        $comic->_check_transcript("Deutsch");
    };
    like($@, qr{duplicated text});
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
    eval {
        $comic->_check_transcript("Deutsch");
    };
    like($@, qr{duplicated text});
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
    $comic->_check_transcript("Deutsch");
    is($@, '');
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
    $comic->_check_transcript("Deutsch");
    is($@, '');
}
