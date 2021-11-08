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


sub order : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            'MetaDeutsch' => [
                {'x' => 0, 'y' => 0, 't' => 'Max'},
                {'x' => 10, 'y' => 0, 't' => 'Paul'},
            ],
            'Deutsch' => [
                {'x' => 5, 'y' => 0, 't' =>'Bier?'},
                {'x' => 15, 'y' => 0, 't' => 'Nein danke!'},
            ],
        }
    );
    my @transcript = $comic->get_transcript('Deutsch');
    is_deeply([@transcript], [ 'Max', 'Bier?', 'Paul', 'Nein danke!']);
}


sub uses_background_text : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            'MetaDeutsch' => [
                {'x' => 0, 'y' => 0, 't' => 'Max'},
                {'x' => 12, 'y' => 0, 't' => 'Paul'},
            ],
            'HintergrundTextDeutsch' => [
                {'x' => 10, 'y' => 0, 't' => 'Fass springt auf'},
            ],
            'HintergrundDeutsch' => [
                {'x' => 10, 'y' => 0, 't' => 'Ignorier das hier'},
            ],
            'Deutsch' => [
                {'x' => 5, 'y' => 0, 't' =>'Bier?'},
                {'x' => 15, 'y' => 0, 't' => 'Nein danke!'},
            ],
        }
    );
    my @transcript = $comic->get_transcript('Deutsch');
    is_deeply([@transcript], [ 'Max', 'Bier?', 'Fass springt auf', 'Paul', 'Nein danke!']);
}


sub container_layer : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="ContainerDeutsch">
        <g inkscape:groupmode="layer" id="layer20" inkscape:label="MetaDeutsch">
            <text x="1" y="1">Max</text>
        </g>
        <g inkscape:groupmode="layer" id="layer21" inkscape:label="MetaDeutsch">
            <text x="10" y="1">Bier!</text>
        </g>
    </g>
XML
    my @transcript = $comic->get_transcript('Deutsch');
    is_deeply([@transcript], [ 'Max', 'Bier!']);
}


sub appends_speech_to_speaker : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            'MetaDeutsch' => [
                {'x' => 0, 'y' => 0, 't' => 'Max:'},
                {'x' => 12, 'y' => 0, 't' => 'Paul:'},
            ],
            'Deutsch' => [
                {'x' => 5, 'y' => 0, 't' =>'Bier?'},
                {'x' => 15, 'y' => 0, 't' => 'Nein danke!'},
            ],
        }
    );
    my @transcript = $comic->get_transcript('Deutsch');
    is_deeply([@transcript], [ 'Max: Bier?', 'Paul: Nein danke!']);
}


sub caches : Tests {
    my $called = 0;
    no warnings qw/redefine/;
    local *Comic::texts_in_language = sub {
        $called++;
        return "foo";
    };
    use warnings;
    my $comic = MockComic::make_comic();

    $comic->get_transcript('Deutsch');
    $comic->get_transcript('Deutsch');

    is($called, 1, 'should have cached');
}
