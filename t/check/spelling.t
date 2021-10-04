use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Comic::Check::Spelling;

__PACKAGE__->runtests() unless caller;

my $check;


sub set_up : Test(setup) {
    MockComic::set_up();

    no warnings qw/redefine/;
    *Text::Aspell::list_dictionaries = sub {
        return ("en:...", "de:...");
    };
    *Text::Aspell::check = sub {
        my ($self, $word) = @_;
        if ($self->get_option("lang") eq "en") {
            return lc $word ne "typpo";
        }
        if ($self->get_option("lang") eq "de") {
            return lc $word ne "tüppfehler";
        }
        return 1;
    };
    use warnings;

    $check = Comic::Check::Spelling->new();
}


sub cut_into_words : Tests {
    is_deeply([Comic::Check::Spelling::_cut_into_words()], []);
    is_deeply([Comic::Check::Spelling::_cut_into_words("")], []);
    is_deeply([Comic::Check::Spelling::_cut_into_words("one")], ["one"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("two words")], ["two", "words"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("words,and punctuation!")], ["words", "and", "punctuation"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("  totally\nspaced \t out  ")], ["totally", "spaced", "out"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("dos\r\nline break")], ["dos", "line", "break"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("1, 2, 3, go!")], ["go"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words(" äh, Jüngchen...")], ["äh", "Jüngchen"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("this isn't good")], ["this", "isn't", "good"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("rock'n'roll")], ["rock'n'roll"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("'nen Bier")], ["'nen", "Bier"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("'quoted'")], ["quoted"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words('"quoted"')], ["quoted"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("#hashtag")], ["hashtag"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("questions?")], ["questions"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("yes!")], ["yes"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("me&you")], ["me", "you"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words("five%")], ["five"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words('@you')], ["you"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words('(light)beer')], ["light", "beer"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words('[light]beer')], ["light", "beer"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words('light-beer')], ["light", "beer"]);
    is_deeply([Comic::Check::Spelling::_cut_into_words('lager/ale')], ["lager", "ale"]);
}


sub has_dictionary_installed : Tests {
    no warnings qw/redefine/;
    local *Text::Aspell::list_dictionaries = sub {
        return (
            "de:de::60:default",
            "de-neu:de:neu:60:default",
            "de_AT:de_AT::60:default",
            "de_CH:de_CH::60:default",
            "de_DE:de_DE::60:default",
            "de_DE:de_DE::60:default",
            "de_DE-neu:de_DE:neu:60:default",
            "en:en::60:default",
            "en-variant_0:en:variant_0:60:default",
            "en-w_accents:en:w_accents:60:default",
            "en-wo_accents:en:wo_accents:60:default",
            "en_US:en_US::60:default",
            "en_US-variant_0:en_US:variant_0:60:default",
            "es:es::60:default");
    };
    use warnings;

    ok($check->_has_dictionary("de"));
    ok($check->_has_dictionary("en"));
    ok($check->_has_dictionary("es"));
    ok(!$check->_has_dictionary("whatever"));
}


sub title_only_no_errors : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Drinking beer"
        }
    );
    $check->check($comic);
    ok(1);
}


sub checks_metadata_text : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Typpo"
        },
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
    );
    $comic->{meta_data}->{allow_duplicated} = [];
    $check->check($comic);
    is_deeply($comic->{warnings}, ["Comic::Check::Spelling: Misspelled in English metadata 'title': 'Typpo'?"]);
}


sub checks_metadata_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer"
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => [ "one", "two", "typpo", "three", "Typpo" ]
        },
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
    );
    $check->check($comic);
    is_deeply($comic->{warnings},
        ["Comic::Check::Spelling: Misspelled in English metadata 'tags': 'typpo'?",
        "Comic::Check::Spelling: Misspelled in English metadata 'tags': 'Typpo'?"]);
}


sub checks_metadata_hash : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer"
        },
        $MockComic::SEE => {
            $MockComic::ENGLISH => { "bym", "typpo" }
        },
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
    );
    $check->check($comic);
    is_deeply($comic->{warnings}, ["Comic::Check::Spelling: Misspelled in English metadata 'see': 'typpo'?"]);
}


sub bails_out_on_objects_in_meta_data : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TAGS => {}
    );
    $comic->{meta_data}->{"foo"}->{"English"} = $check;
    eval {
        $check->check($comic);
    };
    like($@, qr/Cannot spell check a Comic::Check::Spelling/);
}


sub checks_metadata_per_language_ok : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => "Kein Tippfehler",
            $MockComic::ENGLISH => "No typo",
        },
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
        $MockComic::TAGS => {},
    );
    $check->check($comic);
    is_deeply($comic->{warnings}, []);
}


sub checks_metadata_per_language_typos : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => "Ein Tüppfehler",
            $MockComic::ENGLISH => "A typpo",
        },
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
        $MockComic::TAGS => {},
    );
    $check->check($comic);
    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in Deutsch metadata 'title': 'Tüppfehler'?",
        "Comic::Check::Spelling: Misspelled in English metadata 'title': 'typpo'?",
    ]);
}


sub complains_if_no_dictionary_installed_for_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            "Hungarian" => "Sör"
        },
        $MockComic::SETTINGS => {
            $MockComic::DOMAINS => {
                "Hungarian" => "sör-képregény.hu"
            }
        },
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
    );
    $check->check($comic);
    is_deeply($comic->{warnings}, ["Comic::Check::Spelling: No Hungarian (hu) aspell dictionary installed, skipping spell check"]);
}


sub checks_text_layers_no_typo : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {$MockComic::ENGLISH => "Beer!"},
        $MockComic::TEXTS => {$MockComic::ENGLISH => ['no typos here!']});
    $check->check($comic);
    is_deeply($comic->{warnings}, []);
}


sub checks_text_layers_typo : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {$MockComic::ENGLISH => "Beer!"},
        $MockComic::TEXTS => {$MockComic::ENGLISH => ['no typpo here!']},
        $MockComic::PUBLISHED_WHEN => "3000-01-01");
    $check->check($comic);
    is_deeply($comic->{warnings}, ["Comic::Check::Spelling: Misspelled in layer English: 'typpo'?"]);
}


sub checks_text_layers_per_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
            $MockComic::DEUTSCH => "Bier!",
        },
        $MockComic::TAGS => {},
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="0" y="0"><tspan>no typpo here</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
        <text x="0" y="0"><tspan>no meta typpo</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="Deutsch">
        <text x="0" y="0"><tspan>Tüppfehler</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="HintergrundDeutsch">
        <text x="0" y="0"><tspan>meta tüppfehler</tspan></text>
    </g>
XML
    );
    $check->check($comic);
    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in layer Deutsch: 'Tüppfehler'?",
        "Comic::Check::Spelling: Misspelled in layer HintergrundDeutsch: 'tüppfehler'?",
        "Comic::Check::Spelling: Misspelled in layer English: 'typpo'?",
    ]);
}


sub ignore_words_case_insensitive : Tests {
    $check = Comic::Check::Spelling->new(
        "ignore" => {
            "English" => ["typpo"],
            "Deutsch" => "Passtscho"
        });
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Typpo",
            $MockComic::DEUTSCH => "Passtscho",
        },
        $MockComic::TAGS => {},
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
    );
    $check->check($comic);
    is_deeply($comic->{warnings}, []);
}


sub ignore_words_malformed : Tests {
    eval {
        Comic::Check::Spelling->new("ignore" => []);
    };
    like($@, qr/Ignore list must be a hash/);
    eval {
        Comic::Check::Spelling->new(
            "ignore" => {
                "English" => {"TypoTitle" => "alsowrong"},
            });
    };
    like($@, qr/Ignore words must be array or single value/);
}


sub ignore_words_from_comic_meta_data : Tests {
    my $json = <<'JSON';
    "title": {
        "English": "typpo"
    },
    "published": {
        "when": "3000-01-01",
        "where": ""
    },
    "Checks": {
        "use": {
            "Comic::Check::Spelling": {
                "ignore": {
                    "English": ["typpo"]
                }
            }
        }
    },
    "tags": {}
JSON
    my $comic = MockComic::make_comic($MockComic::JSON => $json);
    $comic->{checks}[0]->check($comic);
    is_deeply($comic->{warnings}, []);
}


sub reports_word_in_nested_layers_only_once : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
        },
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="ContainerEnglish">
        <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
            <text x="0" y="0"><tspan>typpo</tspan></text>
        </g>
        <g inkscape:groupmode="layer" inkscape:label="English">
            <text x="0" y="0"><tspan>typpo</tspan></text>
        </g>
        <g inkscape:groupmode="layer" inkscape:label="HintergrundEnglish">
            <text x="0" y="0"><tspan>typpo</tspan></text>
        </g>
        <text x="0" y="0"><tspan>typpo</tspan></text>
    </g>
XML
    );

    $check->check($comic);

    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in layer ContainerEnglish: 'typpo'?",
    ]);
}


sub reports_words_in_title_only_once : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "typpo, typpo, typpo",
        },
    );

    $check->check($comic);

    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in English metadata 'title': 'typpo'?",
    ]);
}


sub resets_reported_words_between_comics : Tests {
    my $comic1 = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "typpo, typpo, typpo",
        },
    );
    my $comic2 = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "typpo, typpo, typpo",
        },
    );

    $check->check($comic1);
    $check->check($comic2);

    is_deeply($comic2->{warnings}, [
        "Comic::Check::Spelling: Misspelled in English metadata 'title': 'typpo'?",
    ]);
}


sub ignores_https_urls : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="0" y="0"><tspan>https://typpo.example.com/some-secure-web-site</tspan></text>
        <text x="0" y="0"><tspan>http://typppo.example.com/some-not-so-secure-web-site</tspan></text>
        <text x="0" y="0"><tspan>https://example.com/some/long/path/with/typpppo</tspan></text>
        <text x="0" y="0"><tspan>https://example.com/some/path?with=query-params&amp;one=typppppo</tspan></text>
    </g>
XML
    );

    $check->check($comic);
    is_deeply($comic->{warnings}, []);
}
