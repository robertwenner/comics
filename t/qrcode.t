use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


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
    *Imager::write = sub {
        (my $self, %write_args) = @_;
        return 1;
    };
    use warnings;
}


sub case_sensitive_8bit : Tests {
    my $comic = MockComic::make_comic();
    $comic->_export_qr_code($MockComic::ENGLISH);
    ok(${$plot_args}{casesensitive}, 'should have passed case-sensitivity flag');
    is(${$plot_args}{mode}, '8-bit', 'should have passed 8bit flag');
}


sub published : Tests {
    my $comic = MockComic::make_comic();
    $comic->_export_qr_code($MockComic::ENGLISH);
    is($text, 'https://beercomics.com/comics/drinking-beer.html', 'Wrong QR code target');
    is($comic->{qrcode}{$MockComic::ENGLISH}, 'drinking-beer.png',
        'Wrong QR image file');
}


sub unpublished_date : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '3000-01-01',
        $MockComic::PUBLISHED_WHERE => 'web');
    $comic->_export_qr_code($MockComic::ENGLISH);
    is($text, 'https://beercomics.com/comics/drinking-beer.html', 'Wrong QR code target');
    is($comic->{qrcode}{$MockComic::ENGLISH}, '../qr/drinking-beer.png',
        'Wrong QR image file');
}


sub unpublished_location : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::PUBLISHED_WHEN => '2000-01-01',
        $MockComic::PUBLISHED_WHERE => 'braumagazin.de');
    $comic->_export_qr_code($MockComic::ENGLISH);
    is($text, 'https://beercomics.com/comics/drinking-beer.html', 'Wrong QR code target');
    is($comic->{qrcode}{$MockComic::ENGLISH}, '../qr/drinking-beer.png',
        'Wrong QR image file');
}


sub writes_qr_code_image_file : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Drinking beer',
        });
    $comic->_export_qr_code($MockComic::ENGLISH);
    MockComic::assert_made_dirs('generated/web/english/comics', 'generated/web/english/qr');
    is($write_args{file}, 'web/english/qr/drinking-beer.png');
}
