use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;

use Comics;
use Comic::Settings;
use lib 't';
use MockComic;
use lib 't/upload';
use DummyUploader;


__PACKAGE__->runtests() unless caller;


my $uploader;
my $comics;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_now(DateTime->new(year => 2022, month => 2, day => 22));

    $uploader = DummyUploader->new();
    $comics = Comics->new();
    push @{$comics->{uploaders}}, $uploader;
}


sub no_comics_still_calls_uploader : Tests {
    $comics->upload_all_comics();

    is($uploader->{called}, 1, 'should have called uploader');
    $uploader->assert_uploaded();
}


sub passes_todays_comics_to_uploader : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2022-02-22',
    );
    push @{$comics->{comics}}, $comic;

    $comics->upload_all_comics();

    is($uploader->{called}, 1, 'should have called uploader');
    $uploader->assert_uploaded($comic);
}


sub passes_no_comics_if_no_current_omes : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2021-02-22', # 1 year ago
    );
    push @{$comics->{comics}}, $comic;

    $comics->upload_all_comics();

    is($uploader->{called}, 1, 'should have called uploader');
    $uploader->assert_uploaded();
}
