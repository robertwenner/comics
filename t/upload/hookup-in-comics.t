use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::Output;

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


sub loads_uploaders_none_configured : Tests {
    $comics = Comics->new();
    $comics->load_uploaders();
    is_deeply($comics->{uploaders}, []);
}


sub loads_uploaders_and_passes_ctor_args : Tests {
    $comics = Comics->new();

    MockComic::fake_file('config.json',
        '{"' . $Comic::Settings::UPLOADERS . '": {"DummyUploader": {"foo": "bar"}}}');
    $comics->load_settings('config.json');

    $comics->load_uploaders();

    my @uploaders = @{$comics->{uploaders}};
    is(@uploaders, 1, 'should have one Uploader');
    $uploaders[0]->assert_constructed('foo', 'bar');
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


sub passes_no_comics_if_no_current_ones : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2021-02-22', # 1 year ago
    );
    push @{$comics->{comics}}, $comic;

    $comics->upload_all_comics();

    is($uploader->{called}, 1, 'should have called uploader');
    $uploader->assert_uploaded();
}


sub prints_uploaders_messages : Tests {
    MockComic::fake_file('config.json',
        '{"' . $Comic::Settings::UPLOADERS . '": {"DummyUploader": {"foo": "bar"}}}');
    $comics->load_settings('config.json');

    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2022-02-22',
    );
    push @{$comics->{comics}}, $comic;

    my @output = $comics->upload_all_comics();
    is_deeply(\@output, ['DummyUploader uploaded']);

    stdout_like {
        Comics::upload('config.json');
    } qr{DummyUploader uploaded}m;
}
