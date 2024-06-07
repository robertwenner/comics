use strict;
use warnings;

use File::Util;
use base 'Test::Class';
use Test::More;

use Comics;

use lib 't';
use MockComic;
use lib 't/check';
use DummyCheck;
use lib 't/out';
use DummyGenerator;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub load_settings : Tests {
    my @loaded;

    MockComic::fake_file('one', '{}');
    MockComic::fake_file('two', '{}');
    MockComic::fake_file('three', '{}');
    local *File::Slurper::read_text = sub {
        push @loaded, @_;
        return "{}";
    };
    use warnings;

    my $comics = Comics->new();
    $comics->load_settings("one", "two", "three");

    is_deeply(\@loaded, ["one", "two", "three"]);
}


sub config_does_not_exist : Tests {
    my $comics = Comics->new();
    eval {
        $comics->load_settings("oops");
    };
    like($@, qr{\bnot found\b}i, 'gives reason');
    like($@, qr{\boops\b}, 'includes file name');
}


sub config_is_directory : Tests {
    no warnings qw/redefine/;
    local *File::Util::file_type = sub {
        return ('BINARY', 'DIRECTORY');
    };
    use warnings;

    my $comics = Comics->new();
    eval {
        $comics->load_settings("oops");
    };
    like($@, qr{\bdirectory\b}i, 'gives reason');
    like($@, qr{\boops\b}, 'includes directory name');
}


sub collect_files_adds_files_right_away : Tests {
    MockComic::fake_file($_, '...') foreach (qw(a.svg foo bar.txt));

    my @collection = Comics::collect_files('a.svg', 'foo', 'bar.txt');
    is_deeply([@collection], ['a.svg', 'foo', 'bar.txt']);
}


sub collect_files_recurses_in_directories : Tests {
    my @to_be_found = ('comic.svg', 'other file', 'file.svg~');

    local *File::Util::file_type = sub {
        my ($file) = @_;
        return $file eq 'dir' ? ('BINARY', 'DIRECTORY') : ('PLAIN', 'TEXT');
    };

    local *File::Find::find = sub {
        my ($wanted, @dirs) = @_;
        is_deeply([@dirs], ['dir'], 'passed wrong argument to find');
        foreach my $found (@to_be_found) {
            $File::Find::name = $found;
            $wanted->();
        }
    };
    use warnings;

    is_deeply([Comics::collect_files('dir')], ['comic.svg']);
}


sub has_default_message_file_name : Tests {
    MockComic::fake_file('settings.json', '{ "Checks": {"Comic::Check::DummyCheck": {} } }');

    my $comics = Comics->new();
    $comics->load_settings('settings.json');

    is($comics->{settings}->{settings}->{Checks}->{persistMessages}, 'generated/check-messages.json');
}


sub restores_messages_does_nothing_if_nio_messages_for_that_comic_stored : Tests {
    MockComic::fake_file('generated/check-messages.json', '{"not-some-comic.svg": ["some problem"]}');
    my $comic = MockComic::make_comic();
    my $generator = DummyGenerator->new();
    $generator->{up_to_date} = 1;

    my $comics = Comics->new();
    push @{$comics->{generators}}, $generator;
    push @{$comics->{comics}}, $comic;
    $comics->run_all_checks();

    is_deeply($comic->{warnings}, []);
}


sub restores_messages_in_up_to_date_comic_one_message : Tests {
    MockComic::fake_file('generated/check-messages.json', '{"some_comic.svg": ["some problem"]}');
    my $comic = MockComic::make_comic();
    my $generator = DummyGenerator->new();
    $generator->{up_to_date} = 1;

    my $comics = Comics->new();
    push @{$comics->{generators}}, $generator;
    push @{$comics->{comics}}, $comic;
    $comics->run_all_checks();

    is_deeply($comic->{warnings}, ['some problem']);
}


sub ignores_restores_messages_in_modified_comic : Tests {
    MockComic::fake_file('generated/check-messages.json', '{"some_comic.svg": ["old problem"]}');
    my $comic = MockComic::make_comic();
    my $generator = DummyGenerator->new();
    $generator->{up_to_date} = 0;

    my $comics = Comics->new();
    push @{$comics->{generators}}, $generator;
    push @{$comics->{comics}}, $comic;
    $comics->run_all_checks();

    is_deeply($comic->{warnings}, []);
}


sub persists_messages_to_file : Tests {
    MockComic::fake_file('generated/check-messages.json', '{"old_comic.svg": ["old problem"]}');
    my $old_comic = MockComic::make_comic($MockComic::IN_FILE => 'old_comic.svg');
    my $new_comic = MockComic::make_comic($MockComic::IN_FILE => 'new_comic.svg');
    my $generator = DummyGenerator->new();
    no warnings qw/redefine/;
    local *DummyGenerator::up_to_date = sub {
        my ($self, $comic) = @_;
        return $comic->{srcFile} eq 'old_comic.svg';
    };
    local *Comic::check = sub {
        my ($self) = @_;
        $self->warning('new problem');
    };
    use warnings;

    my $comics = Comics->new();
    push @{$comics->{generators}}, $generator;
    push @{$comics->{comics}}, $old_comic, $new_comic;
    $comics->run_all_checks();

    MockComic::assert_wrote_file_json('generated/check-messages.json', {
        "old_comic.svg" => ["old problem"],
        "new_comic.svg" => ['new problem'],
    });
}


sub clears_messages_file_if_comics_dont_have_messages : Tests {
    MockComic::fake_file('generated/check-messages.json', '{"some_comic.svg": ["some problem"]}');
    my $comic = MockComic::make_comic();
    my $generator = DummyGenerator->new();
    $generator->{up_to_date} = 0;

    my $comics = Comics->new();
    push @{$comics->{generators}}, $generator;
    push @{$comics->{comics}}, $comic;
    $comics->run_all_checks();

    MockComic::assert_wrote_file('generated/check-messages.json', '{}');
}


sub restores_messages_no_message_file : Tests {
    my $comics = Comics->new();
    $comics->run_all_checks();

    ok(1); # Would have died if it failed
}


sub restore_messages_ignores_bad_json : Tests {
    MockComic::fake_file('generated/check-messages.json', 'whatever');

    my $comics = Comics->new();
    $comics->run_all_checks();

    ok(1); # Would have died if it failed
}


sub restores_messages_empty_file : Tests {
    MockComic::fake_file('generated/check-messages.json', '');

    my $comics = Comics->new();
    $comics->run_all_checks();

    ok(1); # Would have died if it failed
}
