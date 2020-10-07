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
    is_deeply($settings->get(), {"arr" => [1, 2, 3]});
}


sub duplicate_keys_takes_last : Tests {
    $settings->load_str('{"key": 1, "key": 2}');
    is_deeply($settings->get(), {"key" => 2});
}


sub get : Tests {
    is_deeply($settings->get(), {});
    $settings->load_str('{"a": 1, "b": "two", "obj": {"aa": 11}, "arr": [7, 8, 9]}');
    is_deeply($settings->get(), {"a" => 1, "b", => "two", "obj" => {"aa" => 11}, "arr" => [7, 8, 9]});
}


sub handles_utf8 : Tests {
    $settings->load_str('{"ä": "ö"}');
    is_deeply($settings->get(), {"ä" => "ö"});
}


sub merge_settings : Tests {
    $settings->load_str('{"a": 1}');
    $settings->load_str('{"b": 2}');
    is_deeply($settings->get(), {"a" => "1", "b" => 2});
}


sub merge_trees : Tests {
    $settings->load_str('{"obj": {"one": 1, "both": "old"}, "arr": [1, 2]}');
    $settings->load_str('{"obj": {"two": 2, "both": "new"}, "arr": [3]}');
    is_deeply($settings->get(), {"obj" => {"one" => 1, "two" => 2, "both" => "new"}, "arr" => [1, 2, 3]});
}


sub cloned_settings : Tests {
    $settings->load_str('{"obj": {"one": 1, "both": "old"}}');
    my $cloned = $settings->clone();
    $cloned->load_str('{"obj": {"two": 2, "both": "new"}}');
    is_deeply($cloned->get(), {"obj" => {"one" => 1, "two" => 2, "both" => "new"}});
    is_deeply($settings->get(), {"obj" => {"one" => 1, "both" => "old"}});
}


sub reject_top_level_array : Tests {
    eval {
        $settings->load_str("[1, 2, 3]");
    };
    like($@, qr{top level array}i);
}
