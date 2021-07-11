use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub meta_data_cache_path : Tests {
    is(Comic::_meta_cache_for('some-comic.svg'), 'generated/tmp/meta/some-comic.json');
    is(Comic::_meta_cache_for('some/folder/some-comic.svg'), 'generated/tmp/meta/some/folder/some-comic.json');
}


sub creates_meta_data_cache_dir : Tests {
    Comic::_meta_cache_for('some-somics.svg');
    MockComic::assert_made_dirs('generated/tmp/meta/');
}


sub creates_meta_data_cache_dir_nested : Tests {
    Comic::_meta_cache_for('some/folder/some-comics.svg');
    MockComic::assert_made_dirs('generated/tmp/meta/some/folder/');
}


sub checks_json_cache : Tests {
    my $called = 0;
    no warnings qw/redefine/;
    local *Comic::_up_to_date = sub {
        is_deeply(['some_comic.svg', 'generated/tmp/meta/some_comic.json'], \@_);
        $called++;
        return 0;
    };
    MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    is(1, $called, 'wrong number of up-to-date checks');
}


sub reads_meta_data_from_cache_and_does_not_recreate_cache : Tests {
    no warnings qw/redefine/;
    local *Comic::_up_to_date = sub {
        return 1;
    };
    use warnings;

    MockComic::fake_file('generated/tmp/meta/some_comic.json', <<JSON);
{
    "title": {
        "English": "some comic"
    },
    "published": {
        "where": "somewhere"
    }
}
JSON

    my $comic = MockComic::make_comic();
    is($comic->{meta_data}{title}{$MockComic::ENGLISH}, "some comic");
    MockComic::assert_wrote_file('generated/tmp/meta/some_comic.json', undef);
}


sub writes_json_cache_if_stale : Tests {
    MockComic::make_comic();
    my $json = JSON::from_json(<<'JSON');
{
    "title": {
        "English": "Drinking beer",
        "Deutsch": "Bier trinken"
    },
    "tags": {
        "Deutsch": [ "Bier", "Craft" ],
        "English": [ "beer", "craft" ]
    },
    "published": {
        "where": "web",
        "when": "2016-08-01"
    }
}
JSON
    MockComic::assert_wrote_file_json('generated/tmp/meta/some_comic.json', $json);
}


sub no_checks_if_cache_used : Tests {
    no warnings qw/redefine/;
    local *Comic::_up_to_date = sub {
        return 1;
    };
    use warnings;

    MockComic::fake_file('generated/tmp/meta/some_comic.json', <<JSON);
{
    "title": {
        "English": "some comic"
    },
    "published": {
        "where": "somewhere"
    }
}
JSON

    my $comic = MockComic::make_comic();
    $comic->check();    # would croak if it failed
}


sub transcript_cache_path : Tests {
    is(Comic::_transcript_cache_for('some_comic.svg', 'English'),
        'generated/tmp/transcript/English/some_comic.txt');
    is(Comic::_transcript_cache_for('some/folder/some_comic.svg', 'English'),
        'generated/tmp/transcript/English/some/folder/some_comic.txt');
}


sub uses_cached_transcript : Tests {
    no warnings qw/redefine/;
    local *Comic::_up_to_date = sub {
        return 1;
    };
    use warnings;

    MockComic::fake_file('generated/tmp/transcript/English/some_comic.txt', <<'TXT');
transcript
goes
here
TXT

    my $comic = MockComic::make_comic();
    is_deeply([$comic->get_transcript('English')], ["transcript", "goes", "here"]);
}


sub caches_transcript : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            'MetaDeutsch' => [
                {'x' => 0, 'y' => 0, 't' => 'Max:'},
                {'x' => 12, 'y' => 0, 't' => 'Paul:'},
            ],
            'Deutsch' => [
                {'x' => 5, 'y' => 0, 't' =>'Bier?'},
                {'x' => 15, 'y' => 0, 't' => 'Nöö...'},
            ],
        }
    );
    $comic->get_transcript('Deutsch');
    MockComic::assert_wrote_file('generated/tmp/transcript/Deutsch/some_comic.txt',
        "Max: Bier?\nPaul: Nöö...");
}
