package Comic::Out::HtmlArchivePage;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;

use Comic::Out::Template;
use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');


=for stopwords Wenner merchantability perlartistic html

=head1 NAME

Comic::Out::HtmlArchivePage - Generates a per-language html page with all published
comics comics in chronological order.

=head1 SYNOPSIS

    my $settings = {
        # ...
    };
    my $archive = Comic::Out::HtmlArchivePage->new($settings);
    $archive->generate_all(@comics);

=head1 DESCRIPTION

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::HtmlArchivePage.

Parameters:

=over 4

=item * B<$settings> Hash reference to settings.

=back

The passed settings need to specify the L<Toolkit> template files and the
output files, both per language.

For example:

    my $settings = {
        'Out' => {
            'HtmlArchivePage' => {
                'template' => {
                    'English' => 'templates/archive-en.templ',
                },
                'outfile' => {
                    'English' => 'generated/web/english/archive.html',
                },
            }
        }
    }
    my $archive = Comic::Out::HtmlArchivePage($settings);

The C<template> defines the L<Toolkit> template to use.

The C<outfile> where the output should go.

=cut

sub new {
    my ($class, $settings) = @ARG;
    my $self = $class->SUPER::new();

    croak('No HtmlArchivePage configuration') unless ($settings->{HtmlArchivePage});
    %{$self->{settings}} = %{$settings->{HtmlArchivePage}};

    croak('Must specify HtmlArchivePage.template') unless ($self->{settings}->{template});
    croak('HtmlArchivePage.template must be an object') unless (ref $self->{settings}->{template} eq 'HASH');
    croak('Must specify languages in HtmlArchivePage.template') unless(keys %{$self->{settings}->{template}});

    croak('Must specify HtmlArchivePage.outfile') unless ($self->{settings}->{outfile});
    croak('HtmlArchivePage.outfile must be an object') unless (ref $self->{settings}->{outfile} eq 'HASH');

    foreach my $language (keys %{$self->{settings}->{template}}) {
        croak "HtmlArchivePage $language in template but not in outfile" unless ($self->{settings}->{outfile}{$language});
    }
    foreach my $language (keys %{$self->{settings}->{outfile}}) {
        croak "HtmlArchivePage $language in outfile but not in template" unless ($self->{settings}->{template}{$language});
    }

    return $self;
}


=head2 generate_all

Generates the archive page using the configured C<template> and writing the
results to the configured C<outfile>.

Parameters:

=over 4

=item * B<@comics> Comics to consider.

=back

Makes these variables available during template processing:

=over 4

=item * B<@comics> array of published comics, sorted from oldest to latest.

=item * B<$modified> last modification date of the latest comic, to be used in
    time stamps in e.g., HTML headers.

=item * B<&notFor> function that takes a comic and a language and returns
    whether the given comic is for the given language. This is useful if you
    want just one template for all languages.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    foreach my $language (sort keys %{$self->{settings}->{template}}) {
        my @published = sort Comic::from_oldest_to_latest grep {
            !$_->not_yet_published() && $_->_is_for($language)
        } @comics;
        next if (!@published);

        my $templ_file = $self->{settings}->{template}{$language};
        my $page = $self->{settings}->{outfile}{$language};
        my %vars;
        $vars{'comics'} = \@comics;
        $vars{'modified'} = $comics[-1]->{modified};
        $vars{'notFor'} = \&Comic::not_for;
        Comic::write_file($page, Comic::Out::Template::templatize('archive', $templ_file, '', %vars));
    }
    return;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Comic module.


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
