package Comic::Out::Sitemap;

use strict;
use warnings;
use utf8;
use Locales unicode => 1;
use English '-no_match_vars';
use Carp;

use Comic::Out::Template;
use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords Wenner merchantability perlartistic notFor


=head1 NAME

Comic::Out::Sitemap - Generates a sitemap for web sites.


=head1 SYNOPSIS

    my $sitemap = Comic::Out::Sitemap->new(%settings);
    $sitemap->generate_all(@comics);


=head1 DESCRIPTION

Generates a sitemap page for all comics, using a Perl L<Template> Toolkit
template. A sitemap can be used to point search engines to pages they should
crawl; see L<https://en.wikipedia.org/wiki/Sitemaps>.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Sitemap.

Parameters:

=over 4

=item * B<%settings> Hash of settings.

=back

The passed settings need to have the C<template> and C<outfile> hashes.

For example:

    my %settings = (
        'outfile' => {
            'English' => 'generated/web/english/sitemap.xml',
        },
        'template' => {
            'English' => 'templates/sitemap.templ',
        },
    );
    my $sitemap = Comic::Out::Sitemap(%settings);

=cut


sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->needs('template', 'hash-or-scalar');
    $self->needs('outfile', 'HASH');
    $self->flag_extra_settings();

    return $self;
}


=head2 generate_all

Generates the sitemaps for the given Comics.

Parameters:

=over 4

=item * B<@comics> Comics to include in the sitemap.

=back

Makes these variables available in the template:

=over  4

=item * B<@comics> array of all comics (published and unpublished).

=item * B<&notFor> function the template needs to call on each comic,
    passing the language. If that function returns C<true>, the comic should be
    skipped. This maps to C<&Comic::not_published_on_the_web>.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my %outfiles = %{$self->{settings}->{outfile}};
    my @sorted = sort Comic::from_oldest_to_latest @comics;

    my %vars;
    $vars{'comics'} = [ @sorted ];
    $vars{'notFor'} = \&Comic::not_published_on_the_web;

    foreach my $language (Comic::Out::Generator::all_languages(@sorted)) {
        my $templ = $self->per_language_setting('template', $language);
        croak("Comic::Out::Sitemap: No $language template configured") unless ($templ);

        my $xml = Comic::Out::Template::templatize('(none)', $templ, $language, %vars);

        my $outfile = $outfiles{$language};
        croak("Comic::Out::Sitemap: No $language output file configured") unless ($outfile);
        Comic::write_file($outfile, $xml);
    }

    return;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Comic module, L<Template>.


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

Copyright (c) 2016 - 2022, Robert Wenner C<< <rwenner@cpan.org> >>.
All rights reserved.

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
