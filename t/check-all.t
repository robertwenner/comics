use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Comic::Check::Title;

__PACKAGE__->runtests() unless caller;


my %called;

sub set_up : Test(setup) {
    MockComic::set_up();
    %called = ();

    no warnings qw/redefine/;
    *Comic::_get_transcript = sub {
        $called{'_get_transcript'}{$_[1]}++;
    };
    *Comic::_check_tags = sub {
        $called{"_check_tags $_[1]"}{$_[2]}++;
    };
    *Comic::_check_empty_texts = sub {
        $called{'_check_empty_texts'}{$_[1]}++;
    };
    *Comic::_check_transcript = sub {
        $called{'_check_transcript'}{$_[1]}++;
    };
    *Comic::_check_series = sub {
        $called{'_check_series'}{$_[1]}++;
    };
    *Comic::_check_persons = sub {
        $called{'_check_persons'}{$_[1]}++;
    };
    *Comic::_check_meta = sub {
        $called{'_check_meta'}{$_[1]}++;
    };

    *Comic::Check::Title::check = sub {
        $called{'_check_title'}++;
    };
    *Comic::Check::DateCollision::check = sub {
        $called{'_check_date_collision'}++;
    };
    *Comic::Check::Weekday::check = sub {
        $called{'_check_weekday'}++;
    };
    *Comic::_check_frames = sub {
        $called{'_check_frames'}++;
    };
    *Comic::_check_dont_publish = sub {
        $called{'_check_dont_publish'} = $_[1];
    };
    use warnings;
}


sub per_file_checks: Tests {
    my $comic = MockComic::make_comic();
    $comic->check('DONT_PUBLISH');
    is($called{'_check_date_collision'}, 1, 'checked date colliion');
    is($called{'_check_weekday'}, 1, 'checked weekday');
    is($called{'_check_frames'}, 1, '_check_frames called');
    is($called{'_check_dont_publish'}, 'DONT_PUBLISH', 'passed marker to _check_dont_publish');
    is($called{'_check_title'}, 1);
}


sub per_language_checks : Tests {
    my $comic = MockComic::make_comic();
    $comic->check('DONT_PUBLISH');
    foreach my $l ($MockComic::ENGLISH, $MockComic::DEUTSCH) {
        foreach my $f ('_get_transcript', '_check_empty_texts',
                '_check_transcript', '_check_series', '_check_persons', '_check_meta') {
            is($called{$f}{$l}, 1, "$f $l called");
        }
    }
}
