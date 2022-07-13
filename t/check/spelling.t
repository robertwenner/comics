use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Carp;
use Comic::Check::Spelling;


__PACKAGE__->runtests() unless caller;


my $check;
my %typos;
my @asked_to_check;


sub set_up : Test(setup) {
    MockComic::set_up();

    no warnings qw/redefine/;
    *Text::SpellChecker::next_word = sub {
        my ($checker) = @_;
        # Code under tests keeps asking for the next unknown word, but the
        # Text::SpellChecker::text always returns the whole text that was
        # initially passed. Only remember it when it's different from what
        # it was last time. That way tests need to pass different texts for
        # each comic text they want to check, but don't get confusingly
        # duplicated texts.
        my $text = $checker->text();
        if (@asked_to_check == 0 || $asked_to_check[-1] ne $text) {
            push @asked_to_check, $text;
            return $typos{$text};
        }
        return undef;
    };
    use warnings;

    %typos = ();
    @asked_to_check = ();
    $check = Comic::Check::Spelling->new();
}


sub ignores_meta_data_scalar : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer title"
        },
        $MockComic::TAGS => {},
    );
    $comic->{meta_data}->{Author} = "me, and don't spell check me";

    $check->check($comic);

    is_deeply(\@asked_to_check, ["Beer title"]);
}


sub ignores_meta_data_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer title"
        },
        $MockComic::TAGS => {},
    );
    $comic->{meta_data}->{'allow-duplicated'} = ['do not spellcheck me'];

    $check->check($comic);

    is_deeply(\@asked_to_check, ["Beer title"]);
}


sub checks_meta_data_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer title"
        },
        $MockComic::TAGS => {},
        'allow-duplicated' => ['blah'],
    );

    $check->check($comic);

    is_deeply(\@asked_to_check, ["Beer title"]);
}


sub checks_meta_data_per_language_scalar : Tests {
    %typos = ('Beer typo' => 'typo');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer typo"
        },
        $MockComic::TAGS => {},
    );

    $check->check($comic);

    is_deeply(\@asked_to_check, ["Beer typo"]);
    is_deeply(
        $comic->{warnings},
        ["Comic::Check::Spelling: Misspelled in English metadata 'title': 'typo'?"]);
}


sub checks_metadata_per_language_array : Tests {
    %typos = ('typpo' => "typpo");
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Title beer"
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => [ "one", "two", "typpo", "three" ]
        },
    );

    $check->check($comic);

    is_deeply([@asked_to_check], ["one", "two", "typpo", "three", "Title beer"]);
    is_deeply(
        $comic->{warnings},
        ["Comic::Check::Spelling: Misspelled in English metadata 'tags': 'typpo'?"]);
}


sub checks_metadata_per_language_hash : Tests {
    %typos = ('typpo' => 'typpo');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Title"
        },
        $MockComic::TAGS => {},
        $MockComic::SEE => {
            $MockComic::ENGLISH => { "bym", "typpo" }
        },
    );

    $check->check($comic);

    is_deeply([@asked_to_check], ["bym", "typpo", "Title"]);
    is_deeply(
        $comic->{warnings},
        ["Comic::Check::Spelling: Misspelled in English metadata 'see': 'typpo'?"]);
}


sub bails_out_on_objects_in_meta_data : Tests {
    my $comic = MockComic::make_comic();
    $comic->{meta_data}->{"foo"}->{"English"} = $check;

    eval {
        $check->check($comic);
    };

    like($@, qr/Cannot spell check a Comic::Check::Spelling/);
}


sub checks_metadata_per_language : Tests {
    %typos = ('Titel Tippfehler' => 'Tippfehler', 'title typo' => 'typo');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => "Titel Tippfehler",
            $MockComic::ENGLISH => "title typo",
        },
        $MockComic::TAGS => {},
    );

    $check->check($comic);

    is_deeply([@asked_to_check], ["Titel Tippfehler", "title typo"]);
    is_deeply(
        $comic->{warnings},
        ["Comic::Check::Spelling: Misspelled in Deutsch metadata 'title': 'Tippfehler'?",
         "Comic::Check::Spelling: Misspelled in English metadata 'title': 'typo'?"]);
}


sub checks_text_layers : Tests {
    %typos = ('no typos here!' => 'typo');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {$MockComic::ENGLISH => "Beer!"},
        $MockComic::TEXTS => {$MockComic::ENGLISH => ['no typos here!']},
        $MockComic::TAGS => {},
    );

    $check->check($comic);

    is_deeply([@asked_to_check], ['Beer!', 'no typos here!']);
    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in layer English: 'typo'?",
    ]);
}


sub checks_text_layers_per_language : Tests {
    %typos = (
        'no typpo here' => 'typpo',
        'Tüppfehler' => 'Tüppfehler',
        'meta tüppfehler' => 'tüppfehler',
        'other typpo' => 'typpo',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
            $MockComic::DEUTSCH => "Bier!",
        },
        $MockComic::TAGS => {},
        $MockComic::PUBLISHED_WHEN => "3000-01-01",
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="Rahmen"/>
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="0" y="0"><tspan>no typpo here</tspan></text>
        <text x="0" y="0"><tspan>other typpo</tspan></text>
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

    is_deeply(
        \@asked_to_check,
        ['Bier!', 'Tüppfehler', 'meta tüppfehler', 'Beer!', 'no typpo here', 'other typpo', 'no meta typpo']);
    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in layer Deutsch: 'Tüppfehler'?",
        "Comic::Check::Spelling: Misspelled in layer HintergrundDeutsch: 'tüppfehler'?",
        "Comic::Check::Spelling: Misspelled in layer English: 'typpo'? (2 times)",
    ]);
}


sub ignore_words_case_insensitive : Tests {
    %typos = ('Typpo' => 'Typpo', 'Passtscho' => 'Passtscho');
    $check = Comic::Check::Spelling->new(
        "ignore" => {
            "English" => ["typpo"],
            "Deutsch" => "passtscho"
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

    is_deeply(
        \@asked_to_check,
        ['Passtscho', 'Typpo']);
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
    %typos = ("typpo" => "typpo");
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

    is_deeply(\@asked_to_check, ["typpo"]);
    is_deeply($comic->{warnings}, []);
}


sub reports_word_in_nested_layers_only_once : Tests {
    %typos = (
        'typpo meta' => 'typpo',
        'typpo normal' => 'typpo',
        'typpo bg' => 'typpo',
        'typpo container' => 'typpo',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
        },
        $MockComic::TAGS => {},
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="ContainerEnglish">
        <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
            <text x="0" y="0"><tspan>typpo meta</tspan></text>
        </g>
        <g inkscape:groupmode="layer" inkscape:label="English">
            <text x="0" y="0"><tspan>typpo normal</tspan></text>
        </g>
        <g inkscape:groupmode="layer" inkscape:label="HintergrundEnglish">
            <text x="0" y="0"><tspan>typpo bg</tspan></text>
        </g>
        <text x="0" y="0"><tspan>typpo container</tspan></text>
    </g>
XML
    );

    $check->check($comic);

    is_deeply(\@asked_to_check, ["Beer!",
        "typpo container", "typpo meta", "typpo normal", "typpo bg",
    ]);
    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in layer ContainerEnglish: 'typpo'?",
        "Comic::Check::Spelling: Misspelled in layer English: 'typpo'?",
        "Comic::Check::Spelling: Misspelled in layer HintergrundEnglish: 'typpo'?",
        "Comic::Check::Spelling: Misspelled in layer MetaEnglish: 'typpo'?",
    ]);
}


sub reports_words_in_meta_data_only_once : Tests {
    %typos = (
        'title here' => 'typpo',
        'tags here' => 'typpo',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "title here",
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => [ "tags here" ],
        },
    );

    $check->check($comic);

    is_deeply(
        \@asked_to_check,
        ['tags here', 'title here']);
    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in English metadata 'tags': 'typpo'?",
        "Comic::Check::Spelling: Misspelled in English metadata 'title': 'typpo'?",
    ]);
}


sub reports_same_typo_in_different_languages : Tests {
    %typos = (
        'title en' => 'typo',
        'title de' => 'typo',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "title en",
            $MockComic::DEUTSCH => "title de",
        },
        $MockComic::TAGS => {}
    );

    $check->check($comic);

    is_deeply(
        \@asked_to_check,
        ['title de', 'title en']);
    is_deeply($comic->{warnings}, [
        "Comic::Check::Spelling: Misspelled in Deutsch metadata 'title': 'typo'?",
        "Comic::Check::Spelling: Misspelled in English metadata 'title': 'typo'?",
    ]);
}


sub resets_reported_words_between_comics : Tests {
    %typos = (
        'title1' => 'typpo',
        'title2' => 'typpo',
    );
    my $comic1 = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "title1",
        },
    );
    my $comic2 = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "title2",
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
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Title at www.example.org',
        },
        $MockComic::TAGS => {},
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="0" y="0"><tspan>secure https://typpo.example.com/some-secure-web-site</tspan></text>
        <text x="0" y="0"><tspan>plain http://typppo.example.com/some-not-so-secure-web-site</tspan></text>
        <text x="0" y="0"><tspan>path HTTPS://example.com/some/long/path/with/typo</tspan></text>
        <text x="0" y="0"><tspan>query https://example.com/some/path?with=query-params&amp;one=typppppo</tspan></text>
    </g>
XML
    );

    $check->check($comic);

    is_deeply(
        \@asked_to_check,
        ['Title at www.example.org', 'secure ', 'plain ', 'path ', 'query ']);
}


sub user_dictionary_not_a_hash : Tests {
    eval {
        Comic::Check::Spelling->new('user_dictionary' => 'file');
    };
    like($@, qr{\buser_dictionary\b}, 'should mention setting');
    like($@, qr{\blanguage .+ file\b}, 'should say what it needs');

    eval {
        Comic::Check::Spelling->new('user_dictionary' => ['file']);
    };
    like($@, qr{\buser_dictionary\b}, 'should mention the setting');
    like($@, qr{\blanguage .+ file\b}, 'should say what it needs');
}


sub user_dictionary_not_found : Tests {
    no warnings qw/redefine/;
    *File::Slurper::read_lines = sub {
        my ($filename) = @_;
        croak "Couldn't open $filename: file not found";
    };
    use warnings;

    eval {
        Comic::Check::Spelling->new('user_dictionary' => {
            'English' => 'does-not-exist.txt'
        });
    };
    like($@, qr{\buser_dictionary\b}, 'should mention the setting');
    like($@, qr{\bfile not found\b}, 'should say what is wrong');
    like($@, qr{\bEnglish\b}, 'should say the language');
    like($@, qr{\bdoes-not-exist\.txt\b}, 'should say the file name');
}


sub ignores_user_dictionary_words_per_language : Tests {
    no warnings qw/redefine/;
    *File::Slurper::read_lines = sub {
        my ($name) = @_;
        return ('dict');
    };
    use warnings;

    $check = Comic::Check::Spelling->new(
        'ignore' => {
            'English' => 'ignored',
        },
        'user_dictionary' => {
            'English' => 'user-dict.txt'
        }
    );
    is_deeply(
        $check->{ignore}{English},
        {'dict' => 1, 'ignored' => 1});
}


sub user_dictionary_plus_ignore_words : Tests {
    no warnings qw/redefine/;
    *File::Slurper::read_lines = sub {
        my ($name) = @_;
        return ('one', 'two', 'three');
    };
    use warnings;

    $check = Comic::Check::Spelling->new('user_dictionary' => {
        'English' => 'user-dict.txt'
    });
    is_deeply(
        $check->{ignore}{English},
        {'one' => 1, 'two' => 1, 'three' => 1});
}


sub trims_whitespace_from_user_dictionary_words : Tests {
    no warnings qw/redefine/;
    *File::Slurper::read_lines = sub {
        my ($name) = @_;
        return (' one', '  two ', "\n", "\r\n", '', "\tthree  ", 'and four');
    };
    use warnings;

    $check = Comic::Check::Spelling->new('user_dictionary' => {
        'English' => 'user-dict.txt'
    });
    is_deeply(
        $check->{ignore}{English},
        {'one' => 1, 'two' => 1, 'three' => 1, 'and four', => 1});
}


sub prints_unknown_words_xml_for_copy_and_pasting_as_ignore_words : Tests {
    %typos = ('foo' => 'foo');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "foo",
        },
    );
    $check->{print_unknown_xml} = 1;

    $check->check($comic);

    like(${$comic->{warnings}}[-1], qr{English}, 'should mention language');
    like(${$comic->{warnings}}[-1], qr{&quot;foo&quot;}, 'should have quoted word');
}


sub prints_unknown_words_xml_for_copy_and_pasting_as_ignre_words_per_language : Tests {
    %typos = (
        'title en' => 'title en',
        'title de' => 'title de',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "title en",
            $MockComic::DEUTSCH => "title de",
        },
    );
    $check->{print_unknown_xml} = 1;

    $check->check($comic);

    like(${$comic->{warnings}}[1], qr{Deutsch}, 'should mention language');
    like(${$comic->{warnings}}[1], qr{&quot;title de&quot;}, 'should have quoted word');
    like(${$comic->{warnings}}[3], qr{English}, 'should mention language');
    like(${$comic->{warnings}}[3], qr{&quot;title en&quot;}, 'should have quoted word');
}


sub prints_unknown_words_xml_for_copy_and_pasting_many_words_per_language : Tests {
    %typos = (
        'foo' => 'foo',
        'bar' => 'bar',
        'baz' => 'baz',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
        },
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="0" y="0"><tspan>foo</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
        <text x="0" y="0"><tspan>bar</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="HintergrundEnglish">
        <text x="0" y="0"><tspan>baz</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MoreEnglish">
        <text x="0" y="0"><tspan>foo</tspan></text>
    </g>
XML
    );
    $check->{print_unknown_xml} = 1;

    $check->check($comic);

    like(${$comic->{warnings}}[-1], qr{English}, 'should mention language');
    like(${$comic->{warnings}}[-1], qr{&quot;bar&quot;, &quot;baz&quot;, &quot;foo&quot;}, 'should have quoted words');
}


sub prints_unknown_words_quoted_for_copy_and_pasting_as_ignore_words : Tests {
    %typos = ('foo' => 'foo');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "foo",
        },
    );
    $check->{print_unknown_quoted} = 1;

    $check->check($comic);

    like(${$comic->{warnings}}[-1], qr{English}, 'should mention language');
    like(${$comic->{warnings}}[-1], qr{"foo"}, 'should have quoted word');
}


sub prints_unknown_words_quoted_for_copy_and_pasting_as_ignre_words_per_language : Tests {
    %typos = (
        'title en' => 'title en',
        'title de' => 'title de',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "title en",
            $MockComic::DEUTSCH => "title de",
        },
    );
    $check->{print_unknown_quoted} = 1;

    $check->check($comic);

    like(${$comic->{warnings}}[1], qr{Deutsch}, 'should mention language');
    like(${$comic->{warnings}}[1], qr{"title de"}, 'should have quoted word');
    like(${$comic->{warnings}}[3], qr{English}, 'should mention language');
    like(${$comic->{warnings}}[3], qr{"title en"}, 'should have quoted word');
}


sub prints_unknown_words_quoted_for_copy_and_pasting_many_words_per_language : Tests {
    %typos = (
        'foo' => 'foo',
        'bar' => 'bar',
        'baz' => 'baz',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
        },
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="0" y="0"><tspan>foo</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
        <text x="0" y="0"><tspan>bar</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="HintergrundEnglish">
        <text x="0" y="0"><tspan>baz</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MoreEnglish">
        <text x="0" y="0"><tspan>foo</tspan></text>
    </g>
XML
    );
    $check->{print_unknown_quoted} = 1;

    $check->check($comic);

    like(${$comic->{warnings}}[-1], qr{English}, 'should mention language');
    like(${$comic->{warnings}}[-1], qr{"bar", "baz", "foo"}, 'should have quoted words');
}


sub prints_unknown_words_lines_for_copy_and_pasting : Tests {
    %typos = (
        'foo' => 'foo',
        'bar' => 'bar',
        'baz' => 'baz',
    );
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => "Beer!",
        },
        $MockComic::XML => <<'XML',
    <g inkscape:groupmode="layer" inkscape:label="English">
        <text x="0" y="0"><tspan>foo</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MetaEnglish">
        <text x="0" y="0"><tspan>bar</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="HintergrundEnglish">
        <text x="0" y="0"><tspan>baz</tspan></text>
    </g>
    <g inkscape:groupmode="layer" inkscape:label="MoreEnglish">
        <text x="0" y="0"><tspan>foo</tspan></text>
    </g>
XML
    );
    $check->{print_unknown_lines} = 1;

    $check->check($comic);

    like(${$comic->{warnings}}[-1], qr{English}, 'should mention language');
    like(${$comic->{warnings}}[-1], qr{\nbar\nbaz\nfoo}m, 'should have words on lines');
}
