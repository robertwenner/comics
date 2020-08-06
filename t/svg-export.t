use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;


__PACKAGE__->runtests() unless caller;


my $exif_tool;
my $wrote_png;
my %png_meta;
my $asked_value;
my @command_lines;
my $system_exit_code;
my $get_value;
my $write_info_exit_code;


sub set_up : Test(setup) {
    MockComic::set_up();

    $exif_tool = Test::MockModule->new('Image::ExifTool');
    $exif_tool->redefine('SetNewValue', sub($;$$%) {
        my ($self, $name, $value) = @_;
        $png_meta{$name} = $value;
    });
    $exif_tool->redefine('WriteInfo', sub($$;$$) {
        $wrote_png= $_[1];
        return $write_info_exit_code;
    });
    $exif_tool->redefine('GetValue', sub($$;$) {
        $asked_value = $_[1];
        return $get_value;
    });
    no warnings qw/redefine/;
    *Comic::_system = sub {
        push @command_lines, @_;
        return $system_exit_code;
    };
    use warnings;

    $wrote_png = undef;
    %png_meta = ();
    $asked_value = undef;
    @command_lines = ();
    $system_exit_code = 0;
    $get_value = undef;
    $write_info_exit_code = 1;
}


sub png_file_name_from_title_in_language : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    like($command_lines[0], qr{ --export-png=.+/latest-comic\.png\b}, 'png file name in inkscape export');
    like($command_lines[1], qr{\blatest-comic\.png\b}, 'png file name in shrink');
}


sub export_commandline : Tests {
    my $comic = MockComic::make_comic();
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    like($command_lines[0], qr{^inkscape }, 'inkscape call');
    like($command_lines[0], qr{ --without-gui }, 'suppresses GUI');
    like($command_lines[0], qr{ --export-png=}, 'give png file name');
    like($command_lines[0], qr{ --export-area-drawing }, 'export area');
    like($command_lines[0], qr{ --export-background=#ffffff}, 'background color');
}


sub export_fails : Tests {
    $system_exit_code = 1;
    my $comic = MockComic::make_comic();
    eval {
        $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    };
    like($@, qr{could not export}i);
}


sub png_meta_information : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    is($png_meta{'Title'}, 'Latest comic', 'title');
    is($png_meta{'Description'}, '', 'description');
    like($png_meta{'CreationTime'}, qr{^\d{4}-\d{2}-\d{2}$}, 'creation time');
    is($png_meta{'URL'}, 'https://beercomics.com/comics/latest-comic.html', 'URL');
}


sub png_meta_information_global : Tests {
    my $comic = MockComic::make_comic();
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg',
        'Author' => 'The writer', 'Artist' => 'The painter', 'foo' => 'bar');
    is($png_meta{'Author'}, 'The writer', 'author');
    is($png_meta{'Artist'}, 'The painter', 'artist');
    is($png_meta{'foo'}, 'bar', 'unknown element');
}


sub png_meta_information_from_comic_meta_data : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::JSON => <<'JSON',
"png-meta-data": {
    "Author": "The writer",
    "Artist": "The painter",
    "Copyright": "only by me"
}
JSON
    );
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg',
        'Author' => 'Passed writer', 'Artist' => 'Passed painter');
    is($png_meta{'Author'}, 'The writer', 'author');
    is($png_meta{'Artist'}, 'The painter', 'artist');
    is($png_meta{'Copyright'}, 'only by me', 'copyright');
}


sub png_meta_data_not_a_hash : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::JSON => '"png-meta-data": "foo"',
    );
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg',
        'Author' => 'Passed writer');
    is($png_meta{'Author'}, 'Passed writer', 'author');
    is($png_meta{'Artist'}, undef, 'artist');
    is($png_meta{'Copyright'}, undef, 'copyright');
}


sub reports_error_setting_meta_data : Tests {
    my $comic = MockComic::make_comic();
    $exif_tool->redefine('SetNewValue', sub($;$$%) {
        return (1, "go away");
    });
    eval {
        $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    };
    like($@, qr{cannot set}i);
    like($@, qr{go away});
}


sub png_meta_write : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    like($wrote_png, qr{latest-comic\.png});
}


sub png_meta_write_reports_error : Tests {
    my $comic = MockComic::make_comic();
    $write_info_exit_code = 0;
    $get_value = 'some write error';
    eval {
        $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    };
    like($@, qr{cannot write});
    like($@, qr{some write error});
    is($asked_value, 'Error');
}


sub shrink_png_ok : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH, 'optimized-comic.svg' },
    );
    $comic->_svg_to_png($MockComic::ENGLISH, 'some-comic.svg');
    like($command_lines[1], qr{optipng}, 'opting not found');
    like($command_lines[1], qr{\boptimized-comicsvg\.png\b}, 'png file name');
}


sub moves_from_backlog : Tests {
    my $from;
    my $to;

    no warnings qw/redefine/;
    local *Comic::_up_to_date = sub {
        my ($source, $target) = @_;
        return 1 if ($target !~ m/\.json$/);
    };
    local *Comic::_move = sub {
        ($from, $to) = @_;
        return 1;   # success according to perldoc File::Copy
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->export_png('DONT_PUBLISH', ());

    is($from, "generated/backlog/english/latest-comic.png", 'wrong move source');
    is($to, "generated/web/english/comics/latest-comic.png", 'wrong move target');
}
