use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::ExtraTranscriptLayer;

__PACKAGE__->runtests() unless caller;


my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::ExtraTranscriptLayer->new();
}


sub accepts_meta_prefix_from_comic : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::XML => '<g inkscape:groupmode="layer" inkscape:label="TranscriptorEnglish"/>',
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Transcriptor';

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{No texts in TranscriptorEnglish layer}i);
}


sub bails_out_if_no_meta_prefix_configured : Tests {
    my $comic = MockComic::make_comic();

    eval {
        $check->check($comic);
    };
    like($@, qr{\bconfigured\b}, 'should say what is wrong');
    like($@, qr{\bLayerNames\b}, 'should include top level configuration element');
    like($@, qr{\bTranscriptOnlyPrefix\b}, 'should include configuration element');
}


sub bails_out_if_meta_prefix_is_empty : Tests {
    my $comic = MockComic::make_comic();
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = '';

    eval {
        $check->check($comic);
    };
    like($@, qr{\bempty\b}, 'should say what is wrong');
    like($@, qr{\bLayerNames\b}, 'should include top level configuration element');
    like($@, qr{\bTranscriptOnlyPrefix\b}, 'should include configuration element');
}


sub no_meta_layer_checks_other_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3000-01-01',
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Meta';

    $check->check($comic);

    is_deeply($comic->{warnings}, [
        "Comic::Check::ExtraTranscriptLayer: No MetaDeutsch layer",
        "Comic::Check::ExtraTranscriptLayer: No MetaEnglish layer",
    ]);
}


sub no_text_in_meta_layer : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::XML => <<'XML',
    <g
        inkscape:groupmode="layer"
        inkscape:label="MetaEnglish"/>
XML
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Meta';

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{No texts in MetaEnglish layer}i);
}


sub first_text_must_be_from_meta_layer : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::FRAMES => [0, 0, 100, -100],
        $MockComic::XML => <<'XML',
    <g
        inkscape:groupmode="layer"
        inkscape:label="English">
        <text x="0" y="-50">
            <tspan>bottom speech bubble</tspan>
        </text>
    </g>
    <g
        inkscape:groupmode="layer"
        inkscape:label="MetaEnglish">
        <text x="10" y="-10">
            <tspan>top meta</tspan>
        </text>
    </g>
XML
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Meta';

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{First text must be from MetaEnglish}i);
}


sub first_text_must_be_from_meta_layer_no_texts : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::FRAMES => [0, 0, 100, -100],
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English"/>
    <g inkscape:groupmode="layer" inkscape:label="MetaEnglish"/>
XML
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Meta';

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{No texts in MetaEnglish layer});
}


sub does_not_rely_on_order_in_xml : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::FRAMES => [0, 0, 100, 100],
        $MockComic::XML => <<'XML',
    <g
        inkscape:groupmode="layer"
        inkscape:label="English">
        <text x="0" y="-50">
            <tspan>down</tspan>
        </text>
    </g>
    <g
        inkscape:groupmode="layer"
        inkscape:label="MetaEnglish">
        <text x="5" y="-10">
            <tspan>meta top</tspan>
        </text>
    </g>
XML
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Meta';

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{First text must be from MetaEnglish}i);
    like(${$comic->{warnings}}[0], qr{'down' from layer English});
}


sub all_good : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::FRAMES => [0, 0, 100, 100],
        $MockComic::XML => <<'XML',
    <g
        inkscape:groupmode="layer"
        inkscape:label="MetaEnglish">
        <text x="0" y="0">
            <tspan>Intro</tspan>
        </text>
    </g>
XML
    );
    $comic->{settings}->{LayerNames}->{TranscriptOnlyPrefix} = 'Meta';

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}
