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
    $settings->load_str('{"arr": [1, 2, 3,],}');
    my $cloned = $settings->clone();
    is_deeply($cloned->{"arr"}, [1, 2, 3]);
}


sub duplicate_keys_in_json_takes_last : Tests {
    $settings->load_str('{"key": 1, "key": 2}');
    my $cloned = $settings->clone();
    is($cloned->{"key"}, 2);
}


sub handles_utf8_in_json : Tests {
    $settings->load_str('{"ä": "ö"}');
    my $cloned = $settings->clone();
    is($cloned->{"ä"}, "ö");
}


sub merge_json_values : Tests {
    $settings->load_str('{"a": 1}');
    $settings->load_str('{"b": 2}');
    my $cloned = $settings->clone();
    is($cloned->{"a"}, "1");
    is($cloned->{"b"}, 2);
}


sub merge_json_trees : Tests {
    $settings->load_str('{"obj": {"one": 1, "both": "old"}, "arr": [1, 2]}');
    $settings->load_str('{"obj": {"two": 2, "both": "new"}, "arr": [3]}');
    my $cloned = $settings->clone();
    is_deeply($cloned->{"obj"}, {"one" => 1, "two" => 2, "both" => "new"});
    is_deeply($cloned->{"arr"}, [1, 2, 3]);
}


sub cloned_settings : Tests {
    $settings->load_str('{"obj": {"one": 1, "both": "old"}}');
    my $cloned = $settings->clone();
    $cloned->{"obj"} = {"two" => 2, "both" => "new"};
    is_deeply($cloned->{"obj"}, {"two" => 2, "both" => "new"});
    is_deeply(${$settings->{settings}}{"obj"}, {"one" => 1, "both" => "old"});
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
