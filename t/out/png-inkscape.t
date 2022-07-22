use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;

use Comic::Out::PngInkscape;


__PACKAGE__->runtests() unless caller;


my $png;
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
        $wrote_png = $_[1];
        return $write_info_exit_code;
    });
    $exif_tool->redefine('GetValue', sub($$;$) {
        $asked_value = $_[1];
        return $get_value;
    });
    $exif_tool->redefine('ImageInfo', sub($) {
        return {
            'ImageHeight' => 'png height',
            'ImageWidth' => 'png width',
        };
    });
    no warnings qw/redefine/;
    *Comic::Out::PngInkscape::_query_inkscape_version = sub {
        return 'Inkscape 0.9';
    };
    *Comic::Out::PngInkscape::_system = sub {
        push @command_lines, @_;
        return $system_exit_code;
    };
    *Comic::Out::PngInkscape::_file_size = sub {
        return 'file size';
    };
    use warnings;

    $wrote_png = undef;
    %png_meta = ();
    $asked_value = undef;
    @command_lines = ();
    $system_exit_code = 0;
    $get_value = undef;
    $write_info_exit_code = 1;

    $png = Comic::Out::PngInkscape->new(
        'outdir' => 'generated',
    );
}


sub ctor_complains_if_no_outdir_configured : Tests {
    eval {
        Comic::Out::PngInkscape->new();
    };
    like($@, qr{Comic::Out::PngInkscape}i, 'should mention module');
    like($@, qr{\boutdir\b}i, 'should mention setting');
}


sub parses_inkscape_version : Tests {
    my $comic = MockComic::make_comic();
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 0.92.5 (2060ec1f9f, 2020-04-08)\n"), "0.9");
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 1.0 (4035a4fb49, 2020-05-01)\n"), "1.0");
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 1.0.2 (e86c870879, 2021-01-15)\n"), "1.0");
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 1.1 (e86c870879, 2021-01-15)\n"), "1.1");
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 1.1.2 (0a00cf5339, 2022-02-04)\n"), "1.1");
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 1.2 (dc2aedaf03, 2022-05-15)\n"), "1.2");
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 1.2.1 (9c6d41e4, 2022-07-14)\n"), "1.2");
    is(Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 10.0.0 (abcdef, 2200-01-01)\n"), "10.0");

    eval {
        Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Whatever 2020...");
    };
    like($@, qr{Cannot figure out}i);
    like($@, qr{Whatever 2020}i);

    eval {
        Comic::Out::PngInkscape::_parse_inkscape_version($comic, "Inkscape 1,3 (whenever)");
    };
    like($@, qr{Cannot figure out}i);
    like($@, qr{Inkscape 1,3}i);
}


sub caches_inkscape_version : Tests {
    my $called = 0;

    no warnings qw/redefine/;
    local *Comic::Out::PngInkscape::_query_inkscape_version = sub {
        $called++;
        return "Inkscape 1.0";
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    $png->_get_inkscape_version($comic);
    $png->_get_inkscape_version($comic);
    is($called, 1, 'should have cached');
}


sub export_command_line_inkscape09 : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::PngInkscape::_get_inkscape_version = sub {
        return "0.9";
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'latest-comic.svg', 'latest-comic.png');
    like($command_lines[0], qr{^inkscape }, 'inkscape call');
    like($command_lines[0], qr{ --without-gui }, 'suppresses GUI');
    like($command_lines[0], qr{ --export-png=\S*\blatest-comic.png}, 'png file name');
    like($command_lines[0], qr{ --export-area-drawing }, 'export area');
    like($command_lines[0], qr{ --export-background=#ffffff}, 'background color');
}


sub export_command_line_inkscape1 : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::PngInkscape::_get_inkscape_version = sub {
        return "1.0";
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'latest-comic.svg', 'latest-comic.png');
    like($command_lines[0], qr{^inkscape }, 'inkscape call');
    unlike($command_lines[0], qr{ --without-gui }, 'old suppresses GUI flag');
    like($command_lines[0], qr{ --export-type=png\b}, 'png file type');
    like($command_lines[0], qr{ --export-filename=\S*\blatest-comic.png\b}, 'png file name');
    like($command_lines[0], qr{\blatest-comic.svg$}, 'input svg file');
    like($command_lines[0], qr{ --export-area-drawing }, 'export area');
    like($command_lines[0], qr{ --export-background=#ffffff}, 'background color');
}


sub export_command_line_inkscape1_1 : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::PngInkscape::_get_inkscape_version = sub {
        return "1.1";
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'latest-comic.svg', 'latest-comic.png');

    like($command_lines[0], qr{^inkscape }, 'inkscape call');
    unlike($command_lines[0], qr{ --without-gui }, 'old suppresses GUI flag');
    like($command_lines[0], qr{ --export-type=png\b}, 'png file type');
    like($command_lines[0], qr{ --export-filename=\S*\blatest-comic.png\b}, 'png file name');
    like($command_lines[0], qr{\blatest-comic.svg$}, 'input svg file');
    like($command_lines[0], qr{ --export-area-drawing }, 'export area');
    like($command_lines[0], qr{ --export-background=#ffffff}, 'background color');
    is_deeply($comic->{warnings}, []);
}


sub export_command_line_inkscape1_2 : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::PngInkscape::_get_inkscape_version = sub {
        return "1.2";
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'latest-comic.svg', 'latest-comic.png');

    like($command_lines[0], qr{^inkscape }, 'inkscape call');
    unlike($command_lines[0], qr{ --without-gui }, 'old suppresses GUI flag');
    like($command_lines[0], qr{ --export-type=png\b}, 'png file type');
    like($command_lines[0], qr{ --export-filename=\S*\blatest-comic.png\b}, 'png file name');
    like($command_lines[0], qr{\blatest-comic.svg$}, 'input svg file');
    like($command_lines[0], qr{ --export-area-drawing }, 'export area');
    like($command_lines[0], qr{ --export-background=#ffffff}, 'background color');
    is_deeply($comic->{warnings}, []);
}


sub export_command_line_future_inkscape : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::PngInkscape::_get_inkscape_version = sub {
        return "11.0";
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::PUBLISHED_WHEN => '2200-01-01',
    );

    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'latest-comic.png');
    like($comic->{warnings}[0], qr{\bInkscape 11\.0\b});
}


sub png_file_name_in_inkscape_command : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'latest-comic.png');
    like($command_lines[0], qr{\blatest-comic\.png\b}, 'png file name in inkscape export');
}


sub export_fails : Tests {
    $system_exit_code = 1;
    my $comic = MockComic::make_comic();
    eval {
        $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');
    };
    like($@, qr{could not export}i);
}


sub png_meta_information : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::TEXTS => {
            $MockComic::ENGLISH => [ "Max:", "have a beer", "or two" ],
        },
    );
    $comic->{url}{$MockComic::ENGLISH} = 'https://beercomics.com/comics/latest-comic.html';

    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');

    is($png_meta{'Title'}, 'Latest comic', 'title');
    is($png_meta{'Description'}, 'Max: have a beer or two', 'description');
    like($png_meta{'CreationTime'}, qr{^\d{4}-\d{2}-\d{2}$}, 'creation time');
    is($png_meta{'URL'}, 'https://beercomics.com/comics/latest-comic.html', 'URL');
}


sub png_meta_information_from_settings : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            'Author' => 'Settings writer',
            'Artist' => 'Settings artist',
            'Copyright' => 'by me',
            $Comic::Settings::CHECKS => [],
            $MockComic::DOMAINS => {
                $MockComic::ENGLISH => 'beercomics.com',
                $MockComic::DEUTSCH => 'biercomics.de',
            },
        },
    );
    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');
    is($png_meta{'Author'}, 'Settings writer', 'author');
    is($png_meta{'Artist'}, 'Settings artist', 'artist');
    is($png_meta{'Copyright'}, 'by me', 'copyright');
}


sub png_meta_information_from_comic_meta_data : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SETTINGS => {
            'Author' => 'Settings writer',
            'Artist' => 'Settings painter',
            $Comic::Settings::CHECKS => [],
            $MockComic::DOMAINS => {
                $MockComic::ENGLISH => 'beercomics.com',
                $MockComic::DEUTSCH => 'biercomics.de',
            },
        },
        $MockComic::JSON => <<'JSON',
"png-meta-data": {
    "Author": "The writer",
    "Artist": "The painter",
    "Copyright": "only by me"
}
JSON
    );
    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');
    is($png_meta{'Author'}, 'The writer', 'author');
    is($png_meta{'Artist'}, 'The painter', 'artist');
    is($png_meta{'Copyright'}, 'only by me', 'copyright');
}


sub reports_error_setting_meta_data : Tests {
    my $comic = MockComic::make_comic();
    $exif_tool->redefine('SetNewValue', sub($;$$%) {
        return (1, "go away");
    });
    eval {
        $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');
    };
    like($@, qr{cannot set}i);
    like($@, qr{go away});
}


sub png_meta_write : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Some comic' },
    );
    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');
    like($wrote_png, qr{some-comic\.png});
}


sub png_meta_write_reports_error : Tests {
    my $comic = MockComic::make_comic();
    $write_info_exit_code = 0;
    $get_value = 'some write error';
    eval {
        $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');
    };
    like($@, qr{cannot write}i);
    like($@, qr{some write error});
    is($asked_value, 'Error');
}


sub optimize_png_ok : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH, 'Optimized comic' },
    );
    Comic::Out::PngInkscape::_optimize_png($comic, 'optimized-comic.png');
    like($command_lines[0], qr{optipng}, 'opting not found');
    like($command_lines[0], qr{\boptimized-comic\.png\b}, 'png file name');
}


sub optimize_png_fails : Tests {
    $system_exit_code = 1;
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH, 'some-comic.svg' },
        $MockComic::PUBLISHED_WHEN => '3000-01-01',
    );
    Comic::Out::PngInkscape::_optimize_png($comic, 'some-comic.png');
    like($comic->{warnings}[0], qr{\boptipng\b});
}


sub moves_from_backlog : Tests {
    my $from;
    my $to;

    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        my ($self, $target) = @_;
        return $target =~ m/\.png$/;
    };
    local *Comic::Out::PngInkscape::_move = sub {
        ($from, $to) = @_;
        return 1;   # success according to perldoc File::Copy
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{$MockComic::ENGLISH} = 'https://...';

    $png->generate($comic);

    is($from, "generated/backlog/english/latest-comic.png", 'wrong move source');
    is($to, "generated/web/english/comics/latest-comic.png", 'wrong move target');
    is($wrote_png, undef, 'should not write png file');
}


sub moves_from_backlog_fails : Tests {
    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        my ($self, $target) = @_;
        return $target =~ m/\.png$/;
    };
    local *Comic::Out::PngInkscape::_move = sub {
        return 0;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );

    eval {
        $png->generate($comic);
    };
    like($@, qr{Cannot move}i, 'should have croaked');
}


sub does_not_generate_if_png_is_up_to_date : Tests {
    my @checked_up_to_date;

    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        my ($self, $target) = @_;
        push @checked_up_to_date, $target;
        return $target !~ m/backlog/ && $target =~ m/\.png$/;
    };
    local *Comic::Out::PngInkscape::_svg_to_png = sub {
        fail("Called _svg_to_png");
    };
    use warnings;
    $get_value = 123;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{'English'} = 'https://beercomics.com/comics/latest-comic.html';
    $comic->{svgFile}{'English'} = 'generated/tmp/svg/english/latest-comic.svg';

    $png->generate($comic); # would have thrown / failed if it tried to generate png

    is_deeply($comic->{pngSize}, {'English' => 'file size'}, 'wrong size');
    is_deeply($comic->{pngFile}, {'English' => 'latest-comic.png'}, 'wrong png file name');
    is_deeply($comic->{imageUrl}, {'English' => 'https://beercomics.com/comics/latest-comic.png'}, 'wrong URL');
    is_deeply($comic->{height}, {'English' => 'png height'}, 'wrong height');
    is_deeply($comic->{width}, {'English' => 'png width'}, 'wrong width');
    is_deeply(\@checked_up_to_date,
        ['generated/backlog/english/latest-comic.png', 'generated/web/english/comics/latest-comic.png'],
        'checked wrong files');
}


sub generates_png_from_svn : Tests {
    my $svg_file;
    my $png_file;

    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        return 0;
    };
    local *Comic::Out::PngInkscape::_svg_to_png = sub {
        ($svg_file, $png_file) = @_[3, 4];
        return;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    $comic->{url}{'English'} = 'https://beercomics.com/comics/latest-comic.html';
    $comic->{svgFile}{'English'} = 'generated/tmp/svg/english/latest-comic.svg';
    $png->generate($comic);

    is($svg_file, 'generated/tmp/svg/english/latest-comic.svg', 'passed wrong svg file');
    is($png_file, 'generated/web/english/comics/latest-comic.png', 'wrong png file');
    is_deeply($comic->{pngFile}, {'English' => 'latest-comic.png'}, 'wrong png file name');
    is_deeply($comic->{pngSize}, {'English' => 'file size'}, 'wrong size');
    is_deeply($comic->{imageUrl}, {'English' => 'https://beercomics.com/comics/latest-comic.png'}, 'wrong URL');
    is_deeply($comic->{height}, {'English' => 'png height'}, 'wrong height');
    is_deeply($comic->{width}, {'English' => 'png width'}, 'wrong width');
}


sub different_image_dimensions_per_language : Tests {
    my $asked = 0;
    $exif_tool = Test::MockModule->new('Image::ExifTool');
    $exif_tool->redefine('ImageInfo', sub($) {
        $asked++;
        return {
            'ImageHeight' => "height $asked",
            'ImageWidth' => "width $asked",
        };
    });
    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        return 0;
    };
    local *Comic::Out::PngInkscape::_svg_to_png = sub {
        return;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            'Deutsch' => 'de',
            'English' => 'en',
        },
    );
    $comic->{url}{'Deutsch'} = 'https://beercomics.com/comics/de.html';
    $comic->{svgFile}{'Deutsch'} = 'generated/tmp/svg/english/de.svg';
    $comic->{url}{'English'} = 'https://beercomics.com/comics/en.html';
    $comic->{svgFile}{'English'} = 'generated/tmp/svg/english/en.svg';
    $png->generate($comic);

    is_deeply($comic->{height},
        {'Deutsch' => 'height 1', 'English' => 'height 2'},
        'wrong height');
    is_deeply($comic->{width},
        {'Deutsch' => 'width 1', 'English' => 'width 2'},
        'wrong width');
}


sub is_up_to_date_backlog : Tests {
    my @asked;

    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        my $self = shift;
        push @asked, @_;
        return 1;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '4000-01-01',
    );
    $png->up_to_date($comic, 'English');

    is_deeply(\@asked, ["$comic->{backlogPath}{English}/$comic->{baseName}{English}.png"]);
}


sub is_up_to_date_published : Tests {
    my @asked;

    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
        my $self = shift;
        push @asked, @_;
        return 1;
    };
    use warnings;

    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2000-01-01',
    );
    $png->up_to_date($comic, 'English');

    is_deeply(\@asked, ["$comic->{dirName}{English}/$comic->{baseName}{English}.png"]);
}
