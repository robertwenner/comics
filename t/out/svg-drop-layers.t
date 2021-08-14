use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

use Comic::Out::SvgPerLanguage;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub count_layers {
    my ($comic, $label) = @_;

    return count_children($comic->{dom}->documentElement(), $label);
}


sub count_children {
    my ($node, $label) = @_;
    my $count = 0;

    if ($node->nodeName() eq 'g' && $node->getAttribute('inkscape:label') eq $label) {
        $count++;
    }
    foreach my $child($node->childNodes()) {
        $count += count_children($child, $label);
    }
    return $count;
}


sub no_such_layer_does_nothing : Tests {
    my $comic = MockComic::make_comic();
    is(count_layers($comic, 'Raw'), 0, 'should not have a raw layer');
    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');
    is(count_layers($comic, 'Raw'), 0, 'should still not have a raw layer');
}


sub ignores_non_layer_elements : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::XML => '<foo inkscape:groupmode="layer" inkscape:label="Raw"/>',
    );
    my $before = $comic->copy_svg();
    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');
    is_deeply($comic->{dom}, $before);
}


sub ignores_if_wrong_group_mode : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::XML => '<g inkscape:groupmode="whatever" inkscape:label="Raw"/>',
    );
    my $before = $comic->copy_svg();
    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');
    is_deeply($comic->{dom}, $before);
}


sub ignores_if_no_group_mode : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::XML => '<g inkscape:label="Raw"/>',
    );
    my $before = $comic->copy_svg();
    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');
    is_deeply($comic->{dom}, $before);
}


sub drops_one_given_layer : Tests {
    my $comic = MockComic::make_comic($MockComic::XML =>
        '<g inkscape:groupmode="layer" inkscape:label="Raw"/>',
    );
    is(count_layers($comic, 'Raw'), 1, 'should initially have the raw layer');
    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');
    is(count_layers($comic, 'Raw'), 0, 'should have removed the raw layer');
}


sub drops_all_given_layers : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<'XML');
        <g inkscape:groupmode="layer" inkscape:label="Raw"/>
        <g inkscape:groupmode="layer" inkscape:label="Cooked"/>
        <g inkscape:groupmode="layer" inkscape:label="Raw"/>
        <g inkscape:groupmode="layer" inkscape:label="Uncooked"/>
XML
    is(count_layers($comic, 'Raw'), 2, 'initial raw layers');
    is(count_layers($comic, 'Uncooked'), 1, 'initial uncooked layers');
    is(count_layers($comic, 'Cooked'), 1, 'initial cooked layers');

    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw', 'Uncooked');
    is(count_layers($comic, 'Raw'), 0, 'raw layers should be removed');
    is(count_layers($comic, 'Uncooked'), 0, 'uncooked layers should be removed');
    is(count_layers($comic, 'Cooked'), 1, 'cooked layer should still be there');
}
