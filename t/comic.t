use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use Test::NoWarnings;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub one_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { 'English' => 'Drinking beer' }
    );
    is_deeply([$comic->languages()], ['English']);
}


sub many_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => 'Drinking beer',
            'Deutsch' => 'Bier trinken',
            'Español' => 'Tomar cerveza',
        },
    );
    is_deeply([sort $comic->languages()], ['Deutsch', 'English', 'Español']);
    ok(!$comic->not_for('Deutsch'));
    ok(!$comic->not_for('English'));
    ok(!$comic->not_for('Español'));
}


sub no_languages : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {},
        $MockComic::TAGS => { $MockComic::ENGLISH => [], },
    );
    is_deeply([sort $comic->languages()], []);
}


sub empty_title_does_not_count_as_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'English' => '',
            'Deutsch' => '   ',
        },
    );
    is_deeply([sort $comic->languages()], []);
    ok($comic->not_for('Deutsch'));
    ok($comic->not_for('English'));
}


sub catches_json_syntax_error : Tests {
    eval {
        MockComic::make_comic($MockComic::JSON => '{');
    };
    like($@, qr{error in json}i);
}


sub parses_json_relaxed : Tests {
    my $xml = <<"HEADER";
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns="http://www.w3.org/2000/svg">
   <metadata id="metadata7">
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:description>{"a": "b",}</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
</svg>
HEADER
    MockComic::fake_file('some-comic.svg', $xml);

    my $comic = Comic->new({}, []);
    eval {
        $comic->load('some-comic.svg');
    };
    is($@, '', 'should not report an error');
    is($comic->{meta_data}->{a}, 'b', 'should have the value from json');
}


sub text_in_top_level_layer : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer19" inkscape:label="English">
        <text>here I am</text>
    </g>
XML

    my @actual_texts = $comic->texts_in_layer('English');

    is_deeply(\@actual_texts, ['here I am'], 'found wrong text');
}


sub text_in_nested_layer : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer19" inkscape:label="ContainerEnglish">
        <text x="1" y="1">up here</text>
        <g inkscape:groupmode="layer" id="layer21" inkscape:label="English">
            <text x="1" y="1">down here</text>
        </g>
    </g>
XML

    my @inner_texts = $comic->texts_in_layer('English');
    is_deeply(\@inner_texts, ['down here'], 'wrong inner layer texts');
    my @outer_texts = $comic->texts_in_layer('ContainerEnglish');
    is_deeply(\@outer_texts, ['up here'], 'wrong outer layer texts');
}


sub text_in_nested_layer_unlabeled_groups : Tests {
    my $comic = MockComic::make_comic($MockComic::XML => <<XML);
    <g inkscape:groupmode="layer" id="layer19" inkscape:label="ContainerEnglish">
        <g inkscape:groupmode="layer" id="layer21" inkscape:label="English">
            <g id="fill123" style="fill:#000000">
                <text>down here</text>
            </g>
        </g>
    </g>
XML

    # tests that there are no undefined variables warnings, in combination with Test::NoWarnings
    my @inner_texts = $comic->texts_in_layer('English');
    is_deeply(\@inner_texts, ['down here'], 'wrong inner layer texts');
}


sub gets_comic_path_from_config : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            'Paths' => {
                'siteComics' => 'comics-path/',
                'published' => 'published-path/',
                'unpublished' => 'unpublished-path/',
            },
            $MockComic::DOMAINS => {
                $MockComic::ENGLISH => 'beercomics.com',
                $MockComic::DEUTSCH => 'biercomics.de',
            },
        },
    );

    is($comic->{siteComicsPath}, 'comics-path/', 'wrong site comics path');
    is(${$comic->{settings}{Paths}}{'siteComics'}, 'comics-path/', 'wrong site comics setting');
    is(${$comic->{settings}{Paths}}{'published'}, 'published-path/', 'wrong backlog setting');
    is(${$comic->{settings}{Paths}}{'unpublished'}, 'unpublished-path/', 'wrong backlog setting');
}
