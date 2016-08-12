use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub in_json_hash : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'DONT_PUBLISH fix me'
        }
    );
    eval {
        $comic->_check_dont_publish();
    };
    like($@, qr{in JSON > title > English: DONT_PUBLISH fix me}i);
}


sub in_json_array : Test {
    my $comic = MockComic::make_comic(
        $MockComic::WHO => { 
            $MockComic::ENGLISH => [ 'one', 'two', 'three DONT_PUBLISH', 'four' ]});
    eval {
        $comic->_check_dont_publish();
    };
    like($@, qr{In JSON > who > English\[3\]: three DONT_PUBLISH}i);
}


sub in_json_top_level_element : Test {
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '&quot;foo&quot;: &quot;DONT_PUBLISH top level&quot;');
    eval {
        $comic->_check_dont_publish();
    };
    like($@, qr{In JSON > foo: DONT_PUBLISH top level}i);
}


sub in_text : Test {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {$MockComic::DEUTSCH => 
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $comic->_check_dont_publish("English");
    };
    like($@, qr{In layer Deutsch: DONT_PUBLISH oops}i);
}
