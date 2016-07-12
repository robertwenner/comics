use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub make_comic {
    my ($title, $file, $lang) = @_;
    $lang = $lang || $MockComic::ENGLISH;

    return MockComic::make_comic(
        $MockComic::TITLE => {$lang => $title},
        $MockComic::IN_FILE => $file);
}


sub duplicated_title : Test {
    my $c1 = make_comic('duplicated title', 'file1.svg');
    my $c2 = make_comic('duplicated title', 'file2.svg');
    $c1->_check_title($MockComic::ENGLISH);
    eval {
        $c2->_check_title($MockComic::ENGLISH);
    };
    like($@, qr/Duplicated English title/i);
}


sub duplicated_title_case_insensitive : Test {
    my $c1 = make_comic('clever title', 'file1.svg');
    my $c2 = make_comic('Clever Title', 'file2.svg');
    $c1->_check_title($MockComic::ENGLISH);
    eval {
        $c2->_check_title($MockComic::ENGLISH);
    };
    like($@, qr/Duplicated English title/i);
}


sub duplicated_title_whitespace : Test {
    my $c1 = make_comic('white spaced', 'file1.svg');
    $c1->_check_title($MockComic::ENGLISH);
    my $c2 = make_comic(' white   spaced', 'file2.svg');
    eval {
        $c2->_check_title($MockComic::ENGLISH);
    };
    like($@, qr/Duplicated English title/i);
}


sub duplicate_title_allowed_in_different_languages : Test {
    my $c1 = make_comic('Hahaha', 'file1.svg', $MockComic::ENGLISH);
    $c1->_check_title($MockComic::ENGLISH);
    my $c2 = make_comic('Hahaha', 'file2.svg', $MockComic::DEUTSCH);
    # This would throw if it failed
    $c2->_check_title($MockComic::DEUTSCH);
    ok(1);
}


sub idempotent : Test {
    my $c = make_comic("idempotent", 'file1.svg', $MockComic::ENGLISH);
    $c->_check_title($MockComic::ENGLISH);
    # This would throw if it failed
    $c->_check_title($MockComic::ENGLISH);
    ok(1);
}
