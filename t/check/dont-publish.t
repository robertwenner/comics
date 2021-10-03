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
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{in JSON > title > English: DONT_PUBLISH fix me}i);
}


sub in_json_array : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => [ 'one', 'two', 'three DONT_PUBLISH', 'four' ]});
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{In JSON > who > English\[3\]: three DONT_PUBLISH}i);
}


sub in_json_top_level_element : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::JSON => '&quot;foo&quot;: &quot;DONT_PUBLISH top level&quot;');
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{In JSON > foo: DONT_PUBLISH top level}i);
}


sub in_text_in_inkscape_layer : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{In Deutsch layer: DONT_PUBLISH oops}i);
}


sub in_text_layer_without_label : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TEXTS => {undef =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{In undef layer: DONT_PUBLISH oops}i);
}


sub multiple_markers_json : Tests {
    $check = Comic::Check::DontPublish->new('FOO', 'DONT', 'PUBLISH');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::TEXTS => {$MockComic::DEUTSCH =>
            ['blah', 'blubb', 'DONT_PUBLISH oops', 'blahblah']});
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{In Deutsch layer: DONT_PUBLISH oops}i);
}


sub multiple_markers_text : Tests {
    $check = Comic::Check::DontPublish->new('FOO', 'DONT', 'PUBLISH');
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::WHO => {
            $MockComic::ENGLISH => [ 'one', 'two', 'three DONT just yet', 'four' ]});
    $check->check($comic);
    like(${$comic->{warnings}}[0], qr{In JSON > who > English\[3\]: three DONT just yet}i);
}
