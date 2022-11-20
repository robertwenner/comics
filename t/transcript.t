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


sub orders_left_to_right_top_to_bottom : Tests {
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
            'TextBackgroundDeutsch' => [
                {'x' => 10, 'y' => 0, 't' => 'Fass springt auf'},
            ],
            'BackgroundDeutsch' => [
                {'x' => 10, 'y' => 0, 't' => 'Ignorier das hier'},
            ],
            'Deutsch' => [
                {'x' => 5, 'y' => 0, 't' =>'Bier?'},
                {'x' => 15, 'y' => 0, 't' => 'Nein danke!'},
            ],
        }
    );
    $comic->{settings}->{LayerNames}->{NoTranscriptPrefix} = 'Background';

    my @transcript = $comic->get_transcript('Deutsch');

    is_deeply([@transcript], [ 'Max', 'Bier?', 'Fass springt auf', 'Paul', 'Nein danke!']);
}


sub container_layer : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer18" inkscape:label="ContainerDeutsch">
        <g inkscape:groupmode="layer" id="layer20" inkscape:label="MetaDeutsch">
            <text x="1" y="1">Max</text>
        </g>
        <g inkscape:groupmode="layer" id="layer21" inkscape:label="Deutsch">
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


sub ignores_unnamed_layers_without_perl_warning : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            '' => [
                {'x' => 5, 'y' => 0, 't' => 'whatever'},
            ],
        }
    );
    my @transcript = $comic->get_transcript('English');
    is_deeply([@transcript], []);
}


sub picks_all_layers_when_names_are_duplicated : Tests {
    my $layers = <<'XML';
<g inkscape:groupmode="layer" inkscape:label="English">
    <text x="0" y="0">
        <tspan>one</tspan>
    </text>
</g>
<g inkscape:groupmode="layer" inkscape:label="English">
    <text x="10" y="0">
        <tspan>two</tspan>
    </text>
</g>
<g inkscape:groupmode="layer" inkscape:label="English">
    <text x="20" y="0">
        <tspan>three</tspan>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $layers);

    my @transcript = $comic->get_transcript('English');

    is_deeply(\@transcript, ['one', 'two', 'three']);
}


sub nested_layers : Tests {
    my $layers = <<'XML';
<g inkscape:groupmode="layer" inkscape:label="English">
    <g inkscape:groupmode="layer" inkscape:label="inner-not-named-with-language">
        <text x="10" y="0">
            <tspan>ignored</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="inner-named-with-English">
        <text x="10" y="0">
            <tspan>text goes here</tspan>
        </text>
    </g>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $layers);

    my @transcript = $comic->get_transcript('English');

    is_deeply(\@transcript, ['text goes here']);
}


sub full_features : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::FRAMES => [
            # width, height, x, y; 0/0 is top left
            100, 100, 0, 0,     # top left frame
            100, 100, 110, 0,   # right of first frame
            100, 100, 0, 110,   # under first frame
            100, 100, 110, 110, # bottom right frame
        ],
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="10" y="50">
            <tspan>text top left</tspan>
        </text>
        <text x="10" y="150">
            <tspan>text bottom left</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="150" y="50">
            <tspan>text top right</tspan>
        </text>
        <text x="150" y="150">
            <tspan>text bottom right</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="BackgroundEnglish">
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
        <text x="-10" y="10">
            <tspan>meta above frames</tspan>
        </text>
        <text x="5" y="50">
            <tspan>meta top left</tspan>
        </text>
        <text x="5" y="150">
            <tspan>meta bottom left</tspan>
        </text>
        <text x="125" y="50">
            <tspan>meta top right</tspan>
        </text>
        <text x="125" y="150">
            <tspan>meta bottom right</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="Deutsch">
        <text x="165" y="-10">
            <tspan>ignore me, wrong language</tspan>
        </text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="IgnoreEnglish">
        <text x="100" y="-100">
            <tspan>ignore me, no transcript prefix</tspan>
        </text>
    </g>
XML
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Meta';
    $comic->{settings}->{LayerNames}->{NoTranscriptPrefix} = 'Ignore';

    is_deeply(
        [$comic->texts_in_language('English')],
        ['meta above frames',
         'meta top left', 'text top left', 'meta top right', 'text top right',
         'meta bottom left', 'text bottom left', 'meta bottom right', 'text bottom right']);
}


sub bad_transcript_value : Tests {
    my $json = <<'JSON';
&quot;title&quot;: {
    &quot;English&quot;: &quot;Beer&quot;
},
&quot;Transcript&quot;: &quot;whatever&quot;
JSON
    my $comic = MockComic::make_comic($MockComic::JSON => $json);
    eval {
        $comic->get_transcript('English');
    };
    like($@, qr{\bTranscript\b}i, 'should mention setting');
    like($@, qr{\bunknown\b}i, 'should say what is wrong');
}


sub from_order_transcript_value : Tests {
    my $json = <<'JSON';
&quot;title&quot;: {
    &quot;English&quot;: &quot;Beer&quot;
},
&quot;Transcript&quot;: &quot;left-to-right&quot;
JSON
    my $comic = MockComic::make_comic(
        $MockComic::JSON => $json,
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


sub from_numeric_ids : Tests {
    my $json = <<'JSON';
&quot;title&quot;: {
    &quot;English&quot;: &quot;Beer&quot;
},
&quot;Transcript&quot;: &quot;from-ids&quot;
JSON
    my $layers = <<'XML';
<g inkscape:groupmode="layer" inkscape:label="English">
    <text id="250" x="0" y="0">
        <tspan>three</tspan>
    </text>
    <text id="30" x="10" y="0">
        <tspan>two</tspan>
    </text>
    <text id="5" x="20" y="0">
        <tspan>one</tspan>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::JSON => $json, $MockComic::XML => $layers);

    my @transcript = $comic->get_transcript('English');

    is_deeply(\@transcript, ['one', 'two', 'three']);
}


sub from_alphanumeric_ids : Tests {
    my $json = <<'JSON';
&quot;title&quot;: {
    &quot;English&quot;: &quot;Beer&quot;
},
&quot;Transcript&quot;: &quot;from-ids&quot;
JSON
    my $layers = <<'XML';
<g inkscape:groupmode="layer" inkscape:label="English">
    <text id="text3" x="0" y="0">
        <tspan>three</tspan>
    </text>
    <text id="text2" x="10" y="0">
        <tspan>two</tspan>
    </text>
    <text id="text1" x="20" y="0">
        <tspan>one</tspan>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::JSON => $json, $MockComic::XML => $layers);

    my @transcript = $comic->get_transcript('English');

    is_deeply(\@transcript, ['one', 'two', 'three']);
}


sub reports_duplicate_ids : Tests {
    my $json = <<'JSON';
&quot;title&quot;: {
    &quot;English&quot;: &quot;Beer&quot;
},
&quot;Transcript&quot;: &quot;from-ids&quot;
JSON
    my $layers = <<'XML';
<g inkscape:groupmode="layer" inkscape:label="English">
    <text id="12345" x="0" y="0">
        <tspan>three</tspan>z
    </text>
    <text id="12345" x="20" y="0">
        <tspan>one</tspan>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::JSON => $json, $MockComic::XML => $layers);

    $comic->get_transcript('English');

    like($comic->{warnings}[0], qr{\bduplicated id\b}i, 'should say what is wrong');
    like($comic->{warnings}[0], qr{\b12345\b}i, 'should say the id');
    like($comic->{warnings}[0], qr{\bthree\b}i, 'should say the first text');
    like($comic->{warnings}[0], qr{\bone\b}i, 'should say the second text');
}


sub reports_numeric_alphanumeric_id_mix : Tests {
    my $json = <<'JSON';
&quot;title&quot;: {
    &quot;English&quot;: &quot;Beer&quot;
},
&quot;Transcript&quot;: &quot;from-ids&quot;
JSON
    my $layers = <<'XML';
<g inkscape:groupmode="layer" inkscape:label="English">
    <text id="1" x="0" y="0">
        <tspan>three</tspan>z
    </text>
    <text id="text12345" x="20" y="0">
        <tspan>one</tspan>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::JSON => $json, $MockComic::XML => $layers);

    $comic->get_transcript('English');

    like($comic->{warnings}[0], qr{\balpha}i, 'should say what is wrong');
    like($comic->{warnings}[0], qr{\btext12345\b}i, 'should say the id');
    like($comic->{warnings}[0], qr{\bone\b}i, 'should say the text');
}
