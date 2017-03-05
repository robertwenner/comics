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


# Should this rather check that no two meta texts come after each other?
# Except in the beginning, where the first is an intro line? 
# So it would have to have a meta first (maybe not always?), then a speaker
# and then...?
#
# intro? (speaker speech+)+
#
# What about a speech bubble, a meta tag describing a picture, and a name tag?
# Do all meta tags need to have trailing colons? Only speaker markers? What
# else would be there?

sub includes_file_name() : Test {
    my $comic = MockComic::make_comic(
        $MockComic::IN_FILE => 'filename',
        $MockComic::TEXTS => {'MetaDeutsch' => ['Paul:', 'Paul']});
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{\bfilename\b});
}


sub includes_language() : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {'MetaDeutsch' => ['Max:', 'Max:']});
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{Deutsch}i);
}


sub same_name_no_content() : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {'MetaDeutsch' => ['Max:', 'Max:']});
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{\[Max:\]\[Max:\]}i);
}


sub different_names_no_content() : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {'MetaDeutsch' => ['Max:', 'Paul:']});
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{\[Max:\]\[Paul:\]}i);
}


sub description_with_colon_speaker() : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {'MetaDeutsch' => ['Es war einmal ein Bier...', 'Paul:', '...']});
    $comic->_check_transcript('Deutsch');
    ok(1);
}


sub same_name_colon_missing() : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {'MetaDeutsch' => ['Paul:', 'Paul']});
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{\[Paul:\]\[Paul\]}i);
}


sub full_context() : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {'MetaDeutsch' => 
            ['one', 'two', 'three', 'Paul:', 'Paul:', 'ignore']});
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{\[one\]\[two\]\[three\]\[Paul:\]\[Paul:\]}i);
}


sub container_layer() : Test {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="ContainerDeutsch">
        <g inkscape:groupmode="layer" id="layer20" inkscape:label="MetaDeutsch">
            <text x="1" y="1">Max:</text>
            <text x="100" y="100">Paul:</text>
        </g>
    </g>
XML
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{\[Max:\]\[Paul:\]}i);
}


sub layer_with_noise() : Test {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="Deutsch">
        <a transform="translate(0, 4)">
            <text x="1" y="1">Max:</text>
            <text x="10" y="1">Paul:</text>
        </a>
    </g>
XML
    eval {
        $comic->_check_transcript('Deutsch');
    };
    like($@, qr{\[Max:\]\[Paul:\]}i);
}
