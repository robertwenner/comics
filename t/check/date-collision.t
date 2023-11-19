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


sub no_dates : Tests {
    my $comic = MockComic::make_comic($MockComic::PUBLISHED_WHEN => undef);
    $check->check($comic);
    ok(1);
}


sub collision : Tests {
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01', $MockComic::IN_FILE => 'one.svg'));
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-02', $MockComic::IN_FILE => 'two.svg'));
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01',
        $MockComic::IN_FILE => 'three.svg',
    );

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{duplicated date}i, 'should give reason');
    like(${$comic->{warnings}}[0], qr{one\.svg}, 'should mention other file');
}


sub collision_ignores_whitespace : Tests {
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-01 ', $MockComic::IN_FILE => 'one.svg'));
    $check->notify(MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2016-01-02', $MockComic::IN_FILE => 'two.svg'));
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => ' 2016-01-01',
        $MockComic::IN_FILE => 'three.svg',
    );

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{duplicated date}i, 'should give reason');
}


sub no_collision_different_languages : Tests {
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

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
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

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
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

    $check->check($comic);

    is_deeply($comic->{warnings}, []);
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

    is_deeply($comic1->{warnings}, []);
    is_deeply($comic2->{warnings}, []);
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

    is_deeply($comic1->{warnings}, []);
    is_deeply($comic2->{warnings}, []);
}


sub warning_if_no_date : Tests {
    my $comic = MockComic::make_comic('date' => undef);

    $check->check($comic);

    is_deeply($comic->{warnings}, ['Comic::Check::DateCollision: no creation date']);
}


sub no_warning_if_created_and_published_on_the_same_day : Tests {
    my $comic = MockComic::make_comic(
        'date' => ' 2023-01-01',
        $MockComic::PUBLISHED_WHEN => '2023-01-01 ',
    );

    $check->check($comic);

    is_deeply($comic->{warnings}, [], 'should not have warnings');
}


sub warning_if_created_after_published : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::DATE => '2023-01-01',
        $MockComic::PUBLISHED_WHEN => '2022-01-01',
    );

    $check->check($comic);

    like(${$comic->{warnings}}[0], qr{before}i, 'should give reason');
}
