use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Comic::Check::Title;

__PACKAGE__->runtests() unless caller;


my $notified;
my %checked;
my %final_checked;

sub set_up : Test(setup) {
    MockComic::set_up();
    $notified = 0;
    %checked = ();
    %final_checked = ();

    no warnings qw/redefine/;

    *Comic::Check::Check::notify = sub {
        $notified++;
    };

    *Comic::_get_transcript = sub {
        $checked{'_get_transcript'}{$_[1]}++;
    };
    *Comic::_check_tags = sub {
        $checked{"_check_tags $_[1]"}{$_[2]}++;
    };
    *Comic::_check_empty_texts = sub {
        $checked{'_check_empty_texts'}{$_[1]}++;
    };
    *Comic::_check_transcript = sub {
        $checked{'_check_transcript'}{$_[1]}++;
    };
    *Comic::Check::Series::check = sub {
        $checked{'_check_series'}++;
    };
    *Comic::_check_persons = sub {
        $checked{'_check_persons'}{$_[1]}++;
    };
    *Comic::_check_meta = sub {
        $checked{'_check_meta'}{$_[1]}++;
    };

    *Comic::Check::Title::check = sub {
        $checked{'_check_title'}++;
    };
    *Comic::Check::DateCollision::check = sub {
        $checked{'_check_date_collision'}++;
    };
    *Comic::Check::Weekday::check = sub {
        $checked{'_check_weekday'}++;
    };
    *Comic::Check::Frames::check = sub {
        $checked{'_check_frames'}++;
    };
    *Comic::Check::DontPublish::check = sub {
        $checked{'_check_dont_publish'}++;
    };

    use warnings;
}


sub per_file_checks: Tests {
    my $comic = MockComic::make_comic();
    $comic->check('DONT_PUBLISH');
    is($checked{'_check_date_collision'}, 1, 'checked date colliion');
    is($checked{'_check_weekday'}, 1, 'checked weekday');
    is($checked{'_check_frames'}, 1, 'checked frames');
    is($checked{'_check_dont_publish'}, 1);
    is($checked{'_check_title'}, 1);
    is($checked{'_check_series'}, 1);
}


sub per_language_checks : Tests {
    my $comic = MockComic::make_comic();
    $comic->check('DONT_PUBLISH');
    foreach my $l ($MockComic::ENGLISH, $MockComic::DEUTSCH) {
        foreach my $f ('_get_transcript', '_check_empty_texts',
                '_check_transcript', '_check_persons', '_check_meta') {
            is($checked{$f}{$l}, 1, "$f $l checked");
        }
    }
}


sub check_cycle_for_cached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 1;
    $comic->check('DONT_PUBLISH');

    ok($notified > 0, 'should have notified about comic');
    is($checked{'_check_series'}, undef, 'should not have checked cached comic');
#    is($final_checked{'_check_series'}, 1, 'should have done final check');
}


sub check_cycle_for_uncached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 0;
    $comic->check('DONT_PUBLISH');

    ok($notified > 0, 'should have notified about comic');
    is($checked{'_check_series'}, 1, 'should have checked');
#    is($final_checked{'_check_series'}, 1, 'should have done final check');
}
