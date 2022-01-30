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
    my @before = sort map { $_->getAttribute('inkscape:label') } $comic->get_all_layers();

    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');

    my @after = sort map { $_->getAttribute('inkscape:label') } $comic->get_all_layers();
    is_deeply(\@after, \@before);
}


sub ignores_non_layer_elements : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::XML => '<foo inkscape:groupmode="layer" inkscape:label="Raw"/>',
    );

    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');

    my @tags = $comic->{dom}->documentElement()->getChildrenByLocalName('foo');
    is(scalar @tags, 1);
}


sub ignores_if_wrong_group_mode : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::XML => '<g inkscape:groupmode="whatever" inkscape:label="Raw"/>',
    );

    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');

    my @tags = $comic->{dom}->documentElement()->getChildrenByLocalName('g');
    is(scalar @tags, 1);
}


sub ignores_if_no_group_mode : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::XML => '<g inkscape:label="Raw"/>',
    );

    Comic::Out::SvgPerLanguage::_drop_top_level_layers($comic->{dom}, 'Raw');

    my @tags = $comic->{dom}->documentElement()->getChildrenByLocalName('g');
    is(scalar @tags, 1);
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


sub rejects_bad_layers_to_drop : Tests {
    eval {
        Comic::Out::SvgPerLanguage->new(
            'outdir' => 'generated/',
            'drop_layers' => {},
        );
    };
    like($@, qr{\bdrop_layers\b}, 'should include the bad parameter name');
    like($@, qr{\bscalar\b}, 'should say what was expected');
    like($@, qr{\barray\b}, 'should say what was expected');
}


sub pass_configured_names_of_layers_to_drop : Tests {
    my @dropped;

    no warnings qw/redefine/;
    local *Comic::Out::SvgPerLanguage::_drop_top_level_layers = sub {
        my ($svg, @layers) = @_;
        push @dropped, @layers;
    };
    local *Comic::Out::SvgPerLanguage::_write = sub {
        # ignore
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'some comic', },
        $MockComic::XML => '<g inkscape:groupmode="layer" inkscape:label="English"/>',
    );
    my $svg = Comic::Out::SvgPerLanguage->new(
        'outdir' => 'generated/',
        'drop_layers' => ['Raw', 'Scan'],
    );

    $svg->generate($comic);

    is_deeply(\@dropped, ['Raw', 'Scan']);
}



sub hide_transcript_layer_from_comic_configuration : Tests {
    my @shown;
    my @hidden;

    no warnings qw/redefine/;
    local *Comic::Out::SvgPerLanguage::_write = sub {
        # ignore
    };
    local *Comic::Out::SvgPerLanguage::_hide_layer = sub {
        foreach my $layer (@_) {
            push @hidden, $layer->getAttribute('inkscape:label');
        }
        return;
    };
    local *Comic::Out::SvgPerLanguage::_show_layer = sub {
        foreach my $layer (@_) {
            push @shown, $layer->getAttribute('inkscape:label');
        }
        return;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Ein Comic',
            $MockComic::ENGLISH => 'some comic',
        },
        $MockComic::XML => '
            <g inkscape:groupmode="layer" inkscape:label="English"/>
            <g inkscape:groupmode="layer" inkscape:label="Deutsch"/>
            <g inkscape:groupmode="layer" inkscape:label="MetaEnglish"/>
            <g inkscape:groupmode="layer" inkscape:label="MetaDeutsch"/>
            <g inkscape:groupmode="layer" inkscape:label="BackgroundEnglish"/>
            <g inkscape:groupmode="layer" inkscape:label="BackgroundDeutsch"/>
        ',
    );
    $comic->{'settings'}->{'LayerNames'}->{'ExtraTranscriptPrefix'} = 'Meta';

    Comic::Out::SvgPerLanguage::_flip_language_layers($comic, 'English');

    is_deeply(['Deutsch', 'MetaEnglish', 'MetaDeutsch', 'BackgroundDeutsch'], \@hidden, 'hid wrong layers');
    is_deeply(['English', 'BackgroundEnglish'], \@shown, 'showed wrong layers');
}
