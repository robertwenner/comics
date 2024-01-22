package Comic::Out::QrCode;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Imager::QRCode;
use File::Path;

use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');


use Readonly;
Readonly::Hash my %IMAGER_DEFAULT_SETTINGS => {
    'casesensitive' => 1,   # URLs are case sensitive
    'mode' => '8-bit',      # URLs may have non-ascii characters
};


=encoding utf8

=for stopwords Wenner merchantability perlartistic


=head1 NAME

Comic::Out::QrCode - Generates a QR code pointing to a Comic's URL.


=head1 SYNOPSIS

    my $qr_code = Comic::Out::QrCode->new();
    $qr_code->generate(@comics);


=head1 DESCRIPTION

The QR code can be included in the comic page, e.g., when the page is
printed, so that readers can scan the code to go to the comic's web page.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::QrCode.

Parameters:

=over 4

=item * B<%settings> Optional hash with settings, as below.

=back

The passed settings must be a structure like this:

    "outdir" => "qr/"
    "Imager::QRCode" => {
        "mode" => "8-bit",
        "casesensitive" => 1,
    }

The C<outdir> defines the directory to place generated QR code images in.
This directory will be created depending on where each Comic for each
language wants its output. See Output Organization in the documentation.

Any option under Imager::QRCode (optional) is passed to the Imager::QRCode
module. See L<Imager::QRCode>. These are the defaults: 8-bit mode because
generated URLs can contain non-ASCII characters, and case sensitive codes
cause paths are case-sensitive.

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->needs('outdir', 'directory');
    $self->optional('Imager::QRCode', 'HASH', undef);
    $self->flag_extra_settings();

    return $self;
}


=head2 generate

Generates QR code(s) for all languages in the given comic.

Parameters:

=over 4

=item * B<@comics> for which comics to write the QR code.

=back

Makes these variables available in the template:

=over 4

=item * B<%qrcode> hash of language to the generated qr code image file name
    (path relative to the general output directory).

=back

=cut

sub generate {
    my ($self, @comics) = @ARG;

    my %imager_settings = %IMAGER_DEFAULT_SETTINGS;
    if ($self->{settings}->{'Imager::QRCode'}) {
        foreach my $key (keys %{$self->{settings}->{'Imager::QRCode'}}) {
            $imager_settings{$key} = $self->{settings}->{'Imager::QRCode'}{$key};
        }
    }

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            my $qrcode = Imager::QRCode::plot_qrcode($comic->{url}{$language}, \%imager_settings);

            my $dir = $comic->outdir($language);
            my $qrdir = $dir . $self->{settings}->{outdir};
            File::Path::make_path($qrdir);

            my $png = "$comic->{baseName}{$language}.png";
            $qrcode->write(file => "$qrdir$png") or $comic->keel_over($qrcode->errstr());
            $comic->{qrcode}{$language} = $self->{settings}->{outdir} . $png;
        }
    }
    return 0;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Comic module.

The Imager::QRCode module, which (at least on Ubuntu) depends on F<libqrencode> 2.0.0 or above.


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

None.


=head1 INCOMPATIBILITIES

None known.


=head1 BUGS AND LIMITATIONS

None known.


=head1 AUTHOR

Robert Wenner  C<< <rwenner@cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright Robert Wenner. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
See L<perlartistic|perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
