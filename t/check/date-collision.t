use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;
use Comic::Check::DateCollision;

__PACKAGE__->runtests() unless caller;

my $check;


sub set_up : Test(setup) {
    MockComic::set_up();
    $check = Comic::Check::DateCollision->new();
}


sub no_dates : Test {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => undef);
    $check->check($comic);
    ok(1);
}


sub collision : Test {
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01', $MockComic::IN_FILE => 'one.svg'));
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-02', $MockComic::IN_FILE => 'two.svg'));
    eval {
        $check->check(MockComic::make_comic(
            $MockComic::PUBLISHED_WHEN => '2016-01-01', $MockComic::IN_FILE => 'three.svg'));
    };
    like($@, qr{duplicated date}i, 'should give reason');
    like($@, qr{three\.svg}, 'should mention files');
    like($@, qr{three\.svg}, 'should mention files');
}


sub collision_ignores_whitespace : Test {
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01 ', $MockComic::IN_FILE => 'one.svg'));
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-02', $MockComic::IN_FILE => 'two.svg'));
    eval {
        $check->check( MockComic::make_comic(
            $MockComic::PUBLISHED_WHEN => ' 2016-01-01', $MockComic::IN_FILE => 'three.svg'));
    };
    like($@, qr{duplicated date}i, 'should give reason');
}


sub no_collision_different_languages : Test {
    $check->notify(MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'not funny in German',
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01'));
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'auf Englisch nicht lustig',
        },
        $MockComic::PUBLISHED_WHEN => '2016-01-01');
    eval {
        $check->check($comic);
    };
    is($@, '');
}


sub no_collision_published_elsewhere : Tests {
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'one.svg'));
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::PUBLISHED_WHERE => 'offline',
        $MockComic::IN_FILE => 'other.svg');
    eval {
        $check->check($comic);
    };
    is($@, '');
}


sub no_collision_different_date : Tests {
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'one.svg'));
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-02',
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'other.svg');
    eval {
        $check->check($comic);
    };
    is($@, '');
}


sub no_collision_not_yet_published_empty: Tests {
    my $comic1 = (MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'one.svg'));
    $check->notify($comic1);
    my $comic2 = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-02',
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'other.svg');
    $check->notify($comic2);

    $check->check($comic1);
    $check->check($comic2);
    ok(1);
}


sub no_collision_not_yet_published_not_given: Tests {
    my $comic1 = (MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => undef,
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'one.svg'));
    $check->notify($comic1);
    my $comic2 = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-02',
        $MockComic::PUBLISHED_WHERE => 'web',
        $MockComic::IN_FILE => 'other.svg');
    $check->notify($comic2);

    $check->check($comic1);
    $check->check($comic2);
    ok(1);
}
