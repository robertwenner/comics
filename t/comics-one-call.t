use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Capture::Tiny;

use Comics;
use Comic::Settings;

use lib 't';
use MockComic;
use lib 't/check';  # so that it finds the dummies
use lib 't/out';
use lib 't/upload';
use lib 't/social';


my $NO_CHECKS = "\"$Comic::Settings::CHECKS\": {}";
my $DUMMY_CHECK = <<"CHECK";
    "$Comic::Settings::CHECKS": {
        "DummyCheck": []
    }
CHECK

my $NO_GENERATORS = "\"$Comic::Settings::GENERATORS\": {}";
my $DUMMY_GENERATOR = <<"GENERATORS";
    "$Comic::Settings::GENERATORS": {
        "DummyGenerator": []
    }
GENERATORS

my $NO_UPLOADERS = "\"$Comic::Settings::UPLOADERS\": {}";
my $DUMMY_UPLOADER = <<"UPLOADERS";
    "$Comic::Settings::UPLOADERS": {
        "DummyUploader": []
    }
UPLOADERS

my $NO_SOCIAL_MEDIA = "\"$Comic::Settings::SOCIAL_MEDIA_POSTERS\": {}";
my $DUMMY_POSTER = <<"POSTERS";
    "$Comic::Settings::SOCIAL_MEDIA_POSTERS": {
        "DummySocialMedia": []
    }
POSTERS


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();

    no warnings qw/redefine/;
    *Comics::collect_files = sub {
        return ("comic.svg");
    };
    *Comic::load = sub {
        my ($self, $file) = @_;
        $self->{srcFile} = $file;
        return;
    };
    use warnings;
}


sub generate_ok : Tests {
    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR
}
CONFIG
    MockComic::fake_file("config.json", $config);
    my $comics = Comics::generate('config.json', 'comics/');

    is(1, @{$comics->{checks}}, 'should have one check');
    is(1, @{$comics->{generators}}, 'should have one output generator');
    is(0, @{$comics->{uploaders}}, 'should not have uploaders');
    is(0, @{$comics->{social_media_posters}}, 'should not have social media posters');

    is(1, @{$comics->{comics}}, 'should have one comic');
}


sub generate_passes_configured_checks_to_comic : Tests {
    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR
}
CONFIG
    MockComic::fake_file("config.json", $config);

    my $comics = Comics::generate('config.json', 'comics/');
    my $comic = ${$comics->{comics}}[0];
    ok(ref $comic->{checks}->{'DummyCheck'});
}


sub generate_passes_empty_checks_to_comic_if_none_configured : Tests {
    my $config = <<"CONFIG";
{
    $DUMMY_GENERATOR
}
CONFIG
    MockComic::fake_file("config.json", $config);
    no warnings qw/redefine/;
    local *Comics::load_checks = sub {
        # Don't use defaults if no checks are configured.
        return;
    };
    use warnings;

    my $comics = Comics::generate('config.json', 'comics/');
    my $comic = ${$comics->{comics}}[0];
    is_deeply($comic->{checks}, {}, 'should have no checks');
}


sub generate_error_if_no_comics : Tests {
    no warnings qw/redefine/;
    local *Comics::collect_files = sub {
        return ();
    };
    use warnings;

    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR
}
CONFIG
    MockComic::fake_file("config.json", $config);
    eval {
        Comics::generate('config.json', '/path/to/comics/');
    };
    like($@, qr{\bno comics\b}i, 'says what is wrong');
    like($@, qr{\W/path/to/comics/\W}m, 'includes where it looked');
}


sub upload_ok : Tests {
    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR,
    $DUMMY_UPLOADER,
}
CONFIG
    MockComic::fake_file("config.json", $config);
    my $comics = Comics::upload("config.json", "comics/");

    is(1, @{$comics->{uploaders}}, 'should have one uploader');
}


sub upload_error_if_no_uploaders : Tests  {
    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR
}
CONFIG
    MockComic::fake_file("config.json", $config);
    eval {
        Comics::upload("config.json", "comics/");
    };
    like($@, qr{no uploaders}i);
}


sub post_to_social_media_ok : Tests {
    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR,
    $DUMMY_UPLOADER,
    $DUMMY_POSTER
}
CONFIG
    MockComic::fake_file("config.json", $config);

    no warnings qw/redefine/;
    local *Comics::_todays_comics = sub {
        return (MockComic::make_comic());
    };
    use warnings;

    my $out = Capture::Tiny::capture_stdout {
        Comics::publish_comic("config.json", "comics/");
    };
    like($out, qr{posted to dummy});
}


sub post_to_social_media_comic_not_from_today : Tests {
    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR,
    $DUMMY_UPLOADER,
    $DUMMY_POSTER
}
CONFIG
    MockComic::fake_file("config.json", $config);

    no warnings qw/redefine/;
    local *Comics::_todays_comics = sub {
        return ();
    };
    use warnings;

    my $out = Capture::Tiny::capture_stdout {
        Comics::publish_comic("config.json", "comics/");
    };
    like($out, qr{\bnot posting\b}i, 'should say what is wrong');
    like($out, qr{\btoday\b}i, 'should say why it is not posting');
}


sub post_to_social_media_error_no_posters : Tests {
    my $config = <<"CONFIG";
{
    $DUMMY_CHECK,
    $DUMMY_GENERATOR,
    $DUMMY_UPLOADER
}
CONFIG
    MockComic::fake_file("config.json", $config);
    eval {
        Comics::publish_comic("config.json", "comics/");
    };
    like($@, qr{no social media posters}i);
}
