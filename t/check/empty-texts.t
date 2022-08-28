use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::EmptyTexts;

__PACKAGE__->runtests() unless caller;


my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::EmptyTexts->new();
}


sub text_tspan_ok : Tests {
    my $xml = <<XML;
<g inkscape:groupmode="layer" inkscape:label="English">
    <text id="1" x="0" y="0"><tspan>text</tspan></text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}


sub text_textpath_tspan_ok : Tests {
    my $xml = <<XML;
<g inkscape:groupmode="layer" inkscape:label="English">
    <text id="16" transform="translate(-6,-10)">
        <textPath xlink:href="#path17912" id="textPath29613">
            <tspan id="tspan28724">The text</tspan>
        </textPath>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}


sub no_tspan : Tests {
    my $xml = <<XML;
<g inkscape:groupmode="layer" inkscape:label="SomethingEnglish">
    <text id="text-123" x="0" y="0"/>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{Empty text}i, 'Should say what is wrong');
    like(${$comic->{warnings}}[0], qr{SomethingEnglish}i, 'Should mention the layer');
    like(${$comic->{warnings}}[0], qr{text-123}i, 'Should mention the id');
}


sub empty_tspan : Tests {
    my $xml = <<XML;
<g inkscape:groupmode="layer" inkscape:label="SomethingEnglish">
    <text id="text-123" x="0" y="0">
        <tspan/>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{Empty text}i, 'Should say what is wrong');
    like(${$comic->{warnings}}[0], qr{SomethingEnglish}i, 'Should mention the layer');
    like(${$comic->{warnings}}[0], qr{text-123}i, 'Should mention the id');
}


sub whitespace_only_tspan : Tests {
    my $xml = <<XML;
<g inkscape:groupmode="layer" inkscape:label="SomethingEnglish">
    <text id="text-123" x="0" y="0">
        <tspan>   </tspan>
    </text>
</g>
XML
    my $comic = MockComic::make_comic($MockComic::XML => $xml);

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{Empty text}i, 'Should say what is wrong');
    like(${$comic->{warnings}}[0], qr{SomethingEnglish}i, 'Should mention the layer');
    like(${$comic->{warnings}}[0], qr{text-123}i, 'Should mention the id');
}
