use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't';
use MockComic;

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


sub no_collision : Test {
    $check->check(MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-01'));
    $check->check(MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-02'));
    $check->check(MockComic::make_comic($MockComic::PUBLISHED_WHEN => '2016-01-03'));
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
    like($@, qr{three\.svg : duplicated date .+ one\.svg});
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
    like($@, qr{three\.svg : duplicated date .+ one\.svg});
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
