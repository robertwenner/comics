use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub in_json_hash : Test {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'DONT_PUBLISH fix me'
        }
    );
    eval {
        $comic->_check_dont_publish('DONT_PUBLISH');
    };
    like($@, qr{in JSON > title > English: DONT_PUBLISH fix me}i);
}


sub in_json_array : Test {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => [ 'one', 'two', 'three DONT_PUBLISH', 'four' ]});
    eval {
        $comic->_check_dont_publish('DONT_PUBLISH');
    };
    like($@, qr{In JSON > who > English\[3\]: three DONT_PUBLISH}i);
}


sub in_json_top_level_element : Test {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::JSON => '&quot;foo&quot;: &quot;DONT_PUBLISH top level&quot;');
    eval {
        $comic->_check_dont_publish('DONT_PUBLISH');
    };
    like($@, qr{In JSON > foo: DONT_PUBLISH top level}i);
}


sub in_text : Test {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $comic->_check_dont_publish('DONT_PUBLISH');
    };
    like($@, qr{In layer Deutsch: DONT_PUBLISH oops}i);
}


sub silent_if_not_yet_published : Test {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $comic->_check_dont_publish('DONT_PUBLISH');
    };
    is($@, '');
}


sub silent_if_no_published_date : Test {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $comic->_check_dont_publish('DONT_PUBLISH');
    };
    is($@, '');
}
