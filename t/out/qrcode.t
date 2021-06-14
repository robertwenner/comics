use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Out::QrCode;


__PACKAGE__->runtests() unless caller;


my $qrcode;
my $text;
my $plot_args;
my %write_args;


sub setup : Test(setup) {
    MockComic::set_up();

    no warnings qw/redefine/;
    *Imager::QRCode::plot_qrcode = sub {
        ($text, $plot_args) = @_;
        return Imager->new;
    };
    *Imager::write = sub {  # no typo, this is the underlying write method
        (my $self, %write_args) = @_;
        return 1;
    };
    use warnings;

    $qrcode = Comic::Out::QrCode->new();
}


sub passes_default_options_to_imager_qr_code : Tests {
    my $comic = MockComic::make_comic();
    $qrcode->generate($comic);
    ok(${$plot_args}{casesensitive}, 'should have passed case-sensitivity flag');
    is(${$plot_args}{mode}, '8-bit', 'should have passed 8bit flag');
}


sub imager_qrcode_options_override_defaults : Tests {
    my $comic = MockComic::make_comic();
    $qrcode = Comic::Out::QrCode->new({
        'Out' => {
            'QrCode' => {
                'Imager::QRCode' => {
                    'mode' => 'ascii',
                },
            },
        },
    });
    $qrcode->generate($comic);
    ok(${$plot_args}{casesensitive}, 'should have default case-sensitivity flag');
    is(${$plot_args}{mode}, 'ascii', 'should have passed overridden mode flag');
}


sub empty_options_uses_defaults : Tests {
    my $comic = MockComic::make_comic();
    $qrcode = Comic::Out::QrCode->new({});
    $qrcode->generate($comic);
    ok(${$plot_args}{casesensitive}, 'should have default case-sensitivity flag');
    is(${$plot_args}{mode}, '8-bit', 'should have default mode flag');
}


sub empty_out_options_uses_defaults : Tests {
    my $comic = MockComic::make_comic();
    $qrcode = Comic::Out::QrCode->new({
        'Out' => {},
    });
    $qrcode->generate($comic);
    ok(${$plot_args}{casesensitive}, 'should have default case-sensitivity flag');
    is(${$plot_args}{mode}, '8-bit', 'should have default mode flag');
}


sub empty_qrcode_options_uses_defaults : Tests {
    my $comic = MockComic::make_comic();
    $qrcode = Comic::Out::QrCode->new({
        'Out' => {
            'QrCode' => {
            },
        },
    });
    $qrcode->generate($comic);
    ok(${$plot_args}{casesensitive}, 'should have default case-sensitivity flag');
    is(${$plot_args}{mode}, '8-bit', 'should have default mode flag');
}


sub uses_outdir_option : Tests {
    my $comic = MockComic::make_comic();
    $qrcode = Comic::Out::QrCode->new({
        'Out' => {
            'QrCode' => {
                'outdir' => 'my-qr-codes-dir',
            },
        },
    });
    $qrcode->generate($comic);
    is($comic->{qrcode}{$MockComic::ENGLISH}, 'my-qr-codes-dir/drinking-beer.png', 'Wrong QR image file');
}


sub creates_qrcode_in_published_comic : Tests {
    my $comic = MockComic::make_comic();
    $qrcode->generate($comic);
    is($text, 'https://beercomics.com/comics/drinking-beer.html', 'Wrong QR code target');
    is($comic->{qrcode}{$MockComic::ENGLISH}, 'qr/drinking-beer.png', 'Wrong QR image file');
}


sub creates_qr_code_in_not_yet_published_comic : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3000-01-01',
        $MockComic::PUBLISHED_WHERE => 'web');
    $qrcode->generate($comic);
    is($text, 'https://beercomics.com/comics/drinking-beer.html', 'Wrong QR code target');
    is($comic->{qrcode}{$MockComic::ENGLISH}, 'qr/drinking-beer.png', 'Wrong QR image file');
}


sub creates_qr_code_in_non_web_comic : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2000-01-01',
        $MockComic::PUBLISHED_WHERE => 'braumagazin.de');
    $qrcode->generate($comic);
    is($text, 'https://beercomics.com/comics/drinking-beer.html', 'Wrong QR code target');
    is($comic->{qrcode}{$MockComic::ENGLISH}, 'qr/drinking-beer.png', 'Wrong QR image file');
}


sub writes_qr_code_image_file : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Drinking beer',
    });
    $qrcode->generate($comic);
    MockComic::assert_made_dirs('generated/tmp/meta/', 'generated/web/english/comics', 'generated/web/english/', 'generated/web/english/qr/');
    is($write_args{file}, 'generated/web/english/qr/drinking-beer.png');
}


sub reports_file_writing_error : Tests {
    no warnings qw/redefine/;
    local *Imager::write = sub {  # no typo, this is the underlying write method
        return 0;
    };
    local *Imager::errstr = sub {
        return "oops";
    };
    use warnings;

    my $comic = MockComic::make_comic();
    eval {
        $qrcode->generate($comic);
    };
    like($@, qr{\boops\b});
}
