package Comic::Out::Sitemap;

use strict;
use warnings;
use utf8;
use Locales unicode => 1;
use English '-no_match_vars';
use Carp;
use Readonly;

use Comic::Out::Template;
use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');


=for stopwords Wenner merchantability perlartistic notFor

=head1 NAME

Comic::Out::Sitemap - Generates a sitemap for web sites.

=head1 SYNOPSIS

    my $sitemap = Comic::Out::Sitemap->new(\%settings);
    $sitemap->generate_all(@comics);

=head1 DESCRIPTION

Generates a sitemap page for all comics, using a Perl L<Template> Toolkit
template. A sitemap can be used to point search engines to pages they should
crawl; see L<https://en.wikipedia.org/wiki/Sitemaps>.

The template file name and output file must be given in the configuration
for each language like this:

    {
        "Out": {
            "Sitemap": {
                "output": {
                    "English": "generated/web/english/sitemap.xml",
                    "Deutsch": "generated/web/deutsch/sitemap.xml"
                },
                "Templates": {
                    "English": "templates/comic-page.templ",
                    "Deutsch": "templates/comic-page.templ"
                }
            }
        }
    }

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Sitemap.

Parameters:

=over 4

=item * B<$settings> Hash reference to settings.

=back

The passed settings need to have the C<Template> and C<output> hashes.

For example:

    my $settings = {
        'Out' => {
            'Sitemap' => {
                'output' => {
                    'English' => 'generated/web/english/sitemap.xml',
                },
                'Templates' => {
                    'English' => 'templates/sitemap.templ',
                },
            },
        },
    }
    my $sitemap = Comic::Out::Sitemap($settings);

=cut


sub new {
    my ($class, $settings) = @ARG;
    my $self = bless{}, $class;

    croak('No Sitemap configuration') unless ($settings->{Sitemap});
    %{$self->{settings}} = %{$settings->{Sitemap}};

    croak('Must specify Sitemap.Templates') unless ($self->{settings}->{Templates});
    croak('Must specify Sitemap.output') unless ($self->{settings}->{output});

    return $self;
}


=head2 generate_all

Generates the sitemaps for the given Comics.

Parameters:

=over 4

=item * B<@comics> Comics to include in the sitemap.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my %site_map_templates = %{$self->{settings}->{Templates}};
    my %outputs = %{$self->{settings}->{output}};
    my @sorted = sort Comic::from_oldest_to_latest @comics;

    my %vars;
    $vars{'comics'} = [ @sorted ];
    $vars{'notFor'} = \&Comic::_not_published_on_the_web;

    foreach my $language (_all_comic_languages(@sorted)) {
        my $templ = $site_map_templates{$language};
        croak("No $language template configured") unless ($templ);

        my $xml = Comic::Out::Template::templatize('(none)', $templ, $language, %vars);

        my $output = $outputs{$language};
        croak("No $language output file configured") unless ($output);
        Comic::write_file($output, $xml);
    }

    return;
}


sub _all_comic_languages {
    my (@comics) = @ARG;

    my %languages;
    foreach my $c (@comics) {
        foreach my $language ($c->languages()) {
            $languages{$language} = 1;
        }
    }
    return keys %languages;
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

Copyright (c) 2016 - 2021, Robert Wenner C<< <rwenner@cpan.org> >>.
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
