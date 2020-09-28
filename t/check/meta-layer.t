use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::MetaLayer;

__PACKAGE__->runtests() unless caller;


my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::MetaLayer->new();
}


sub no_meta_layer : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" });
    eval {
        $check->check($comic);
    };
    like($@, qr{No MetaEnglish layer}i);
}


sub no_text_in_meta_layer : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => "funny comic" },
        $MockComic::XML => <<'XML',
    <g
        inkscape:groupmode="layer"
        inkscape:label="MetaEnglish"/>
XML
    );
    eval {
        $check->check($comic);
    };
    like($@, qr{No texts in MetaEnglish layer}i);
}


sub first_text_must_be_from_meta_layer : Test {
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
        <text x="0" y="-100">
            <tspan>top meta</tspan>
        </text>
    </g>
XML
    );
    eval {
        $check->check($comic);
    };
    like($@, qr{First text must be from MetaEnglish}i);
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
    eval {
        $check->check($comic);
    };
    like($@, qr{No texts in MetaEnglish layer});
}


sub does_not_rely_on_order_in_xml : Test {
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
        <text x="0" y="0">
            <tspan>meta top</tspan>
        </text>
    </g>
XML
    );
    eval {
        $check->check($comic);
    };
    like($@, qr{First text must be from MetaEnglish}i);
}


sub all_good : Test {
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
    eval {
        $check->check($comic);
    };
    is($@, '');
}
