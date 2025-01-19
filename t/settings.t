use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Comic::Settings;

__PACKAGE__->runtests() unless caller;


my $settings;


sub set_up : Test(setup) {
    $settings = Comic::Settings->new();
}


sub relaxed_json : Tests {
    $settings->load_str('{"Out": [1, 2, 3,],}');
    my $cloned = $settings->clone();
    is_deeply($cloned->{"Out"}, [1, 2, 3]);
}


sub duplicate_keys_in_json_takes_last : Tests {
    $settings->load_str('{"Out": 1, "Out": 2}');
    my $cloned = $settings->clone();
    is($cloned->{"Out"}, 2);
}


sub handles_utf8_in_json : Tests {
    $settings->load_str('{"Out": {"ä": "ö"}}');
    my $cloned = $settings->clone();
    is($cloned->{"Out"}->{"ä"}, "ö");
}


sub merge_json_values : Tests {
    $settings->load_str('{"Out": {"a": 1}}');
    $settings->load_str('{"Out": {"b": 2}}');
    my $cloned = $settings->clone();
    is($cloned->{'Out'}->{"a"}, "1");
    is($cloned->{'Out'}->{"b"}, 2);
}


sub merge_json_trees : Tests {
    $settings->load_str('{"Checks": 1, "Out": "old", "Uploader": [1, 2]}');
    $settings->load_str('{"Social": 2, "Out": "new", "Uploader": [3]}');
    my $cloned = $settings->clone();
    is_deeply($cloned->{"Checks"}, 1);
    is_deeply($cloned->{"Social"}, 2);
    is_deeply($cloned->{"Out"}, "new");
    is_deeply($cloned->{"Uploader"}, [1, 2, 3]);
}


sub cloned_settings : Tests {
    $settings->load_str('{"Checks": 1, "Out": "old"}');
    my $cloned = $settings->clone();
    $cloned->{"Out"} = {"two" => 2, "both" => "new"};
    is_deeply($cloned->{"Out"}, {"two" => 2, "both" => "new"});
    is_deeply($settings->{settings}->{"Checks"}, 1);
    is_deeply($settings->{settings}->{"Out"}, "old");
}


sub load_json_rejects_top_level_array : Tests {
    eval {
        $settings->load_str("[1, 2, 3]");
    };
    like($@, qr{top level array}i);
}


sub merges_loaded_and_default_settings : Tests {
    $settings->load_str('{"Paths": { "published": "ontheweb/"}}');
    my $cloned = $settings->clone();
    is($cloned->{Paths}{'siteComics'}, 'comics/');
    is($cloned->{Paths}{'published'}, 'ontheweb/');
}


sub normalizes_paths : Tests {
    $settings->load_str('{"Paths": { "published": "ontheweb"}}');
    my $cloned = $settings->clone();
    is($cloned->{Paths}{'published'}, 'ontheweb/');
}


sub uses_defaults : Tests {
    my $cloned = $settings->clone();
    is_deeply($cloned, {
        'Paths' => {
            'siteComics' => 'comics/',
            'published' => 'generated/web/',
            'unpublished' => 'generated/backlog/',
        },
        'LayerNames' => {
            "TranscriptOnlyPrefix" => "Meta",
            "NoTranscriptPrefix" => "NoText",
            "Frames" => "Frames",
        },
        'Checks' => {
            'persistMessages' => 'generated/check-messages.json',
        },
    });
}


sub complains_if_paths_is_not_a_hash : Tests {
    eval {
        $settings->load_str('{ "Paths": [] }');
    };
    like($@, qr{\bPaths\b}, 'should mention the top level setting');
    like($@, qr{\bhash\b}, 'should say what is wrong');
}


sub complains_if_paths_hash_is_empty : Tests {
    eval {
        $settings->load_str('{ "Paths": {} }');
    };
    like($@, qr{\bPaths\b}, 'should mention the top level setting');
    like($@, qr{\bempty\b}, 'should say what is wrong');
}


sub complains_if_comics_path_not_a_scalar : Tests {
    eval {
        $settings->load_str('{ "Paths": { "siteComics": [] } }');
    };
    like($@, qr{\bPaths\b}, 'should mention the top level setting');
    like($@, qr{\bsiteComics\b}, 'should mention the actual setting');
    like($@, qr{\bsingle value\b}, 'should say what is wrong');
}


sub complains_about_unknown_top_level_objects : Tests {
    eval {
        $settings->load_str('{ "Whatever": {} }');
    };
    like($@, qr{\bWhatever\b}, 'should mention the top level setting');
    like($@, qr{\bunknown\b}i, 'should say what is wrong');
}
