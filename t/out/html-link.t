use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Out::HtmlLink;


__PACKAGE__->runtests() unless caller;


my $htmllink;


sub set_up : Test(setup) {
    MockComic::set_up();
    $htmllink = Comic::Out::HtmlLink->new({'Comic::Out::HtmlLink' => {}});
}


sub no_see : Tests {
    my $comic = MockComic::make_comic();
    $htmllink->generate_all(($comic));
    is_deeply($comic->{htmllink}, {'Deutsch' => {}, 'English' => {}}, 'should not have references');
}


sub empty_see : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
            },
        },
    );
    $htmllink->generate_all(($comic));
    is_deeply($comic->{htmllink}, {'Deutsch' => {}, 'English' => {}}, 'should not have references');
}


sub dead_link : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "some comic" => "oops.svg",
            },
        },
        $MockComic::IN_FILE => 'referrer.svg',
    );
    eval {
        $htmllink->generate_all(($comic));
    };
    like($@, qr{referrer\.svg}, 'should include referred file');
    like($@, qr{English}, 'should include language of the reference');
    like($@, qr{oops\.svg}, 'should include comic that has the bad refernce');
}


sub link_exact_match : Tests {
    my $referenced = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'The original',
        },
        $MockComic::IN_FILE => 'comics/web/original.svg',
    );
    my $referrer = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "the original comic" => "comics/web/original.svg",
            }
        },
    );
    $htmllink->generate_all($referenced, $referrer);
    is_deeply($referrer->{htmllink}->{'English'}, {'the original comic' => 'the-original.html'});
}


sub link_file_name_only : Tests {
    my $referenced = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'The original',
        },
        $MockComic::IN_FILE => 'comics/web/original.svg',
    );
    my $referrer = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "the original comic" => "original.svg",
            }
        },
    );
    $htmllink->generate_all($referenced, $referrer);
    is_deeply($referrer->{htmllink}->{'English'}, {'the original comic' => 'the-original.html'});
}


sub link_file_not_unique : Tests {
    my $candidate_one = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Candidate 1',
        },
        $MockComic::IN_FILE => 'comics/web/original.svg',
    );
    my $candidate_two = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Candidate 2',
        },
        $MockComic::IN_FILE => 'comics/other-web/original.svg',
    );
    my $referrer = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "the original comic" => "original.svg",
            }
        },
    );
    eval {
        $htmllink->generate_all($candidate_one, $candidate_two, $referrer);
    };
    like($@, qr{matches}, 'should say what is wrong');
    like($@, qr{original\.svg}, 'should mention link');
    like($@, qr{comics/web/original\.svg}, 'should mention first candidate');
    like($@, qr{comics/other-web/original\.svg}, 'should mention second candidate');
}


sub test_picks_more_specific_over_more_generic : Tests {
    my $candidate_one = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Candidate 1',
        },
        $MockComic::IN_FILE => '/somewhere/else/original.svg',
    );
    my $candidate_two = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Candidate 2',
        },
        $MockComic::IN_FILE => 'original.svg',
    );
    my $referrer = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "the original comic" => "original.svg",
            }
        },
    );
    $htmllink->generate_all($candidate_one, $candidate_two, $referrer);
    is_deeply($referrer->{htmllink}->{'English'}, {'the original comic' => 'candidate-2.html'});
}
