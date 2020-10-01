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

    *Comic::_check_transcript = sub {
        $checked{'_check_transcript'}{$_[1]}++;
    };

    *Comic::Check::Tag::check = sub {
        $checked{"check_tags"}++;
    };
    *Comic::Check::EmptyTexts::check = sub {
        $checked{'check_empty_texts'}++;
    };
    *Comic::Check::MetaLayer::check = sub {
        $checked{'check_meta'}++;
    };
    *Comic::Check::Series::check = sub {
        $checked{'check_series'}++;
    };
    *Comic::Check::Actors::check = sub {
        $checked{'check_actors'}++;
    };
    *Comic::Check::Title::check = sub {
        $checked{'check_title'}++;
    };
    *Comic::Check::DateCollision::check = sub {
        $checked{'check_date_collision'}++;
    };
    *Comic::Check::Weekday::check = sub {
        $checked{'check_weekday'}++;
    };
    *Comic::Check::Frames::check = sub {
        $checked{'check_frames'}++;
    };
    *Comic::Check::DontPublish::check = sub {
        $checked{'check_dont_publish'}++;
    };

    use warnings;
}


sub per_file_checks: Tests {
    my $comic = MockComic::make_comic();
    $comic->check('DONT_PUBLISH');
    is($checked{'check_date_collision'}, 1, 'checked date colliion');
    is($checked{'check_weekday'}, 1, 'checked weekday');
    is($checked{'check_frames'}, 1, 'checked frames');
    is($checked{'check_dont_publish'}, 1);
    is($checked{'check_title'}, 1);
    is($checked{'check_series'}, 1);
    is($checked{'check_actors'}, 1);
    is($checked{'check_meta'}, 1);
    is($checked{'check_tags'}, 1);
    is($checked{'check_empty_texts'}, 1);
}


sub per_language_checks : Tests {
    my $comic = MockComic::make_comic();
    $comic->check('DONT_PUBLISH');
    foreach my $l ($MockComic::ENGLISH, $MockComic::DEUTSCH) {
        foreach my $f ('_check_transcript') {
            is($checked{$f}{$l}, 1, "$f $l checked");
        }
    }
}


sub check_cycle_for_cached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 1;
    $comic->check('DONT_PUBLISH');

    ok($notified > 0, 'should have notified about comic');
    is($checked{'check_series'}, undef, 'should not have checked cached comic');
#    is($final_checked{'check_series'}, 1, 'should have done final check');
}


sub check_cycle_for_uncached_comic : Tests {
    my $comic = MockComic::make_comic();
    $comic->{use_meta_data_cache} = 0;
    $comic->check('DONT_PUBLISH');

    ok($notified > 0, 'should have notified about comic');
    is($checked{'check_series'}, 1, 'should have checked comic');
#    is($final_checked{'check_series'}, 1, 'should have done final check');
}
