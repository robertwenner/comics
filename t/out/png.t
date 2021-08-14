use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use Test::MockModule;
use lib 't';
use MockComic;

use Comic::Out::Png;


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
        $wrote_png= $_[1];
        return $write_info_exit_code;
    });
    $exif_tool->redefine('GetValue', sub($$;$) {
        $asked_value = $_[1];
        return $get_value;
    });
    no warnings qw/redefine/;
    *Comic::Out::Png::_query_inkscape_version = sub {
        return 'Inkscape 0.9';
    };
    *Comic::Out::Png::_system = sub {
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

    $png = Comic::Out::Png->new({
        'Png' => {
            'outdir' => 'generated',
        },
    });
}


sub ctor_complains_if_no_config : Tests {
    eval {
        Comic::Out::Png->new();
    };
    like($@, qr{no png configuration}i);
    eval {
        Comic::Out::Png->new({
            'Png' => {},
        });
    };
    like($@, qr{\boutdir\b}i);
}


sub ctor_adds_trailing_slash_to_outdir : Tests {
    $png = Comic::Out::Png->new({
        'Png' => {
            'outdir' => 'generated/',
        },
    });
    is($png->{settings}->{outdir}, 'generated/');
    $png = Comic::Out::Png->new({
        'Png' => {
            'outdir' => 'generated',
        },
    });
    is($png->{settings}->{outdir}, 'generated/');
}


sub ctor_override_temp_dir : Tests {
    $png = Comic::Out::Png->new({
        'Png' => {
            'outdir' => 'generated',
        },
    });
    like($png->{settings}->{tempdir}, qr{^\S+$}, 'should use default temp dir');
    $png = Comic::Out::Png->new({
        'Png' => {
            'outdir' => 'generated',
            'tempdir' => '/tmp/dir/test/',
        },
    });
    is($png->{settings}->{tempdir}, '/tmp/dir/test/', 'should override temp dir');
}


sub parses_inkscape_version : Tests {
    my $comic = MockComic::make_comic();
    is(Comic::Out::Png::_parse_inkscape_version($comic, "Inkscape 0.92.5 (2060ec1f9f, 2020-04-08)\n"), "0.9");
    is(Comic::Out::Png::_parse_inkscape_version($comic, "Inkscape 1.0 (4035a4fb49, 2020-05-01)\n"), "1.0");
    is(Comic::Out::Png::_parse_inkscape_version($comic, "Inkscape 1.0.2 (e86c870879, 2021-01-15)\n"), "1.0");
    is(Comic::Out::Png::_parse_inkscape_version($comic, "Inkscape 10.0.0 (abcdef, 2200-01-01)\n"), "10.0");

    eval {
        Comic::Out::Png::_parse_inkscape_version($comic, "Whatever 2020...");
    };
    like($@, qr{Cannot figure out}i);
    like($@, qr{Whatever 2020}i);
}


sub caches_inkscape_version : Tests {
    my $called = 0;

    no warnings qw/redefine/;
    local *Comic::Out::Png::_query_inkscape_version = sub {
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
    local *Comic::Out::Png::_get_inkscape_version = sub {
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
    local *Comic::Out::Png::_get_inkscape_version = sub {
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


sub export_command_line_future_inkscape : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::Png::_get_inkscape_version = sub {
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
    );
    $png->_svg_to_png($comic, $MockComic::ENGLISH, 'some-comic.svg', 'some-comic.png');
    is($png_meta{'Title'}, 'Latest comic', 'title');
    is($png_meta{'Description'}, '', 'description');
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
    like($@, qr{cannot write});
    like($@, qr{some write error});
    is($asked_value, 'Error');
}


sub optimize_png_ok : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH, 'Optimized comic' },
    );
    Comic::Out::Png::_optimize_png($comic, 'optimized-comic.png');
    like($command_lines[0], qr{optipng}, 'opting not found');
    like($command_lines[0], qr{\boptimized-comic\.png\b}, 'png file name');
}


sub optimize_png_fails : Tests {
    $system_exit_code = 1;
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH, 'some-comic.svg' },
        $MockComic::PUBLISHED_WHEN => '3000-01-01',
    );
    Comic::Out::Png::_optimize_png($comic, 'some-comic.png');
    like($comic->{warnings}[0], qr{\boptipng\b});
}

__END__
sub generate_ok : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
        $MockComic::TEXTS => {
            $MockComic::ENGLISH => ['burp'],
        },
    );
    $png->generate($comic);

    # Code under test does:
    # check for an existing backlog png
    # check if existing regular output png is up to date
    # _flip_language_layers($comic, $language);
    # my $language_svg = $self->_write_temp_svg_file($comic, $language);
    # $self->_svg_to_png($comic, $language, $language_svg, $png_file);
    # _optimize_png($comic, $png_file);
    # get_png_info
}


sub generate_skips_if_cached: Tests {
    assert called _move
    assert read png info into comic
}


sub generate_fails_if_language_layer_not_found : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Latest comic' },
    );
    eval {
        $png->generate($comic);
    };
    like($@, qr{\blayer\b}, 'should say what is missing');
    like($@, qr{\bEnglish\b}, 'should mention language');
}


sub generate_for_backlog : Tests {
    assert that it uses the right folder
}


sub moves_from_backlog : Tests {
    my $from;
    my $to;

    no warnings qw/redefine/;
    local *Comic::up_to_date = sub {
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
    $comic->export_png();

    is($from, "generated/backlog/english/latest-comic.png", 'wrong move source');
    is($to, "generated/web/english/comics/latest-comic.png", 'wrong move target');
}
