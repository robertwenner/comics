# Exploratory JSON parser test.

use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use JSON;

__PACKAGE__->runtests() unless caller;


sub boolean : Tests {
    my $json = '{ "t": true, "f": false}';
    my $parsed = decode_json($json);
    # is_deeply($parsed, {"t" => '1', "f" => '0'});
    ok($parsed->{"t"});
    ok(!$parsed->{"f"});
    ok(JSON::is_bool($parsed->{"t"}));
    ok(JSON::is_bool($parsed->{"f"}));
}


sub boolean_is_case_sensitive : Tests {
    my $json = '{ "T": True }';
    eval {
        decode_json($json);
    };
    like($@, qr{malformed json}i);
}


sub anything_to_boolean : Tests {
    my $json = '{ "t": "t", "f": "f", "1": 1, "0": 0}';
    my $parsed = decode_json($json);

    ok($parsed->{"t"});
    ok($parsed->{"f"});
    ok($parsed->{"1"});
    ok(!$parsed->{"0"});
}
