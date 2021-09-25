use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Check::DontPublish;


__PACKAGE__->runtests() unless caller;


my $check;

sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::DontPublish->new('DONT_PUBLISH');
}


sub in_json_hash : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'DONT_PUBLISH fix me'
        }
    );
    eval {
        $check->check($comic);
    };
    like($@, qr{in JSON > title > English: DONT_PUBLISH fix me}i);
}


sub in_json_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => [ 'one', 'two', 'three DONT_PUBLISH', 'four' ]});
    eval {
        $check->check($comic);
    };
    like($@, qr{In JSON > who > English\[3\]: three DONT_PUBLISH}i);
}


sub in_json_top_level_element : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::JSON => '&quot;foo&quot;: &quot;DONT_PUBLISH top level&quot;');
    eval {
        $check->check($comic);
    };
    like($@, qr{In JSON > foo: DONT_PUBLISH top level}i);
}


sub in_text_in_inkscape_layer : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $check->check($comic);
    };
    like($@, qr{In Deutsch layer: DONT_PUBLISH oops}i);
}


sub silent_if_not_yet_published : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3016-01-01',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $check->check($comic);
    };
    is($@, '');
}


sub silent_if_no_published_date : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $check->check($comic);
    };
    is($@, '');
}


sub in_text_layer_without_label : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TEXTS => {undef =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $check->check($comic);
    };
    like($@, qr{In undef layer: DONT_PUBLISH oops}i);
}


sub multiple_markers_json : Tests {
    $check = Comic::Check::DontPublish->new('FOO', 'DONT', 'PUBLISH');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    eval {
        $check->check($comic);
    };
    like($@, qr{In Deutsch layer: DONT_PUBLISH oops}i);
}


sub multiple_markers_text : Tests {
    $check = Comic::Check::DontPublish->new('FOO', 'DONT', 'PUBLISH');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => [ 'one', 'two', 'three DONT just yet', 'four' ]});
    eval {
        $check->check($comic);
    };
    like($@, qr{In JSON > who > English\[3\]: three DONT just yet}i);
}
