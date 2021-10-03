use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Check::Title;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub make_comic {
    my ($title, $file, $lang) = @_;
    $lang = $lang || $MockComic::ENGLISH;

    return MockComic::make_comic(
        $MockComic::TITLE => {$lang => $title},
        $MockComic::IN_FILE => $file,
    );
}


sub duplicated_title : Tests {
    my $check = Comic::Check::Title->new();
    $check->check(make_comic('duplicated title', 'file1.svg'));
    my $comic = make_comic('duplicated title', 'file2.svg');

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr/Duplicated English title/i);
}


sub duplicated_title_case_insensitive : Tests {
    my $check = Comic::Check::Title->new();
    $check->check(make_comic('clever title', 'file1.svg'));
    my $comic = make_comic('Clever Title', 'file2.svg');

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr/Duplicated English title/i);
}


sub duplicated_title_whitespace : Tests {
    my $check = Comic::Check::Title->new();
    $check->check(make_comic('white spaced', 'file1.svg'));
    my $comic = make_comic(' white   spaced', 'file2.svg');

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr/Duplicated English title/i);
}


sub duplicate_title_allowed_in_different_languages : Tests {
    my $check = Comic::Check::Title->new();
    $check->check(make_comic('Hahaha', 'file1.svg', $MockComic::ENGLISH));
    my $comic = make_comic('Hahaha', 'file2.svg', $MockComic::DEUTSCH);

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}


sub idempotent : Tests {
    my $check = Comic::Check::Title->new();
    my $comic = make_comic("idempotent", 'file1.svg', $MockComic::ENGLISH);

    $check->check($comic);
    $check->check($comic);

    is_deeply($comic->{warnings}, []);
}
