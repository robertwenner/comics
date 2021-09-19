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
    is($comic->{see}, undef, 'should not have references');
}


sub empty_see : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
            },
        },
    );
    $htmllink->generate_all(($comic));
    is($comic->{htmllink}, undef, 'should not have references');
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
    like($@, qr{oops\.svg}, 'should include comit that has the bad refernce');
}


sub links_to_url : Tests {
    my $referenced = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'The original',
        },
        $MockComic::IN_FILE => 'original.svg',
    );
    my $referrer = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "the original comic" => "original.svg",
            }
        },
        $MockComic::IN_FILE => 'referrer.svg',
    );
    $htmllink->generate_all($referenced, $referrer);
    is_deeply($referrer->{htmllink}->{'English'}, {'the original comic' => 'https://beercomics.com/comics/the-original.html'});
}
