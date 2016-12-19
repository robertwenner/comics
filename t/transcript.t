use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file('template', '[% transcriptHtml %]');
}


sub order : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            'MetaDeutsch' => [
                {'x' => 0, 'y' => 0, 't' => 'Max'},
                {'x' => 10, 'y' => 0, 't' => 'Paul'},
            ],
            'Deutsch' => [
                {'x' => 5, 'y' => 0, 't' =>'Bier?'}, 
                {'x' => 15, 'y' => 0, 't' => 'Nein danke!'},
            ],
        }
    );
    my $wrote = $comic->_do_export_html('Deutsch', 'template');
    is($wrote, "<p>Max</p>\n<p>Bier?</p>\n<p>Paul</p>\n<p>Nein danke!</p>\n");
}


sub merges_speaker_and_speech : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TEXTS => {
            'MetaDeutsch' => [{'x' => 0, 'y' => 0, 't' => 'Max:'}],
            'Deutsch' => [{'x' => 5, 'y' => '0', 't' => 'Bier?'}],
        }
    );
    my $wrote = $comic->_do_export_html('Deutsch', 'template');
    is($wrote, "<p>Max: Bier?</p>\n");
}
