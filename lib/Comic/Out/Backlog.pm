package Comic::Out::Backlog;

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

Comic::Out::Backlog - Generates a single html page with all unpublished
comics plus possibly lists of used tags, series and other per-language
comic meta data.

=head1 SYNOPSIS

    my %settings = {
        # ...
    };
    my $png = Comic::Out::Backlog->new(%settings);
    $png->generate_all(@comics);

=head1 DESCRIPTION

The backlog is language-independent, i.e., all languages are included in the
same backlog page.

This module needs to go after any image generation so that it can refer to
image files of comics in the backlog. (From a HTML generating point order
would not matter, but the template processing code will die if the file name
variable is not yet defined.)

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Backlog.

Parameters:

=over 4

=item * B<$settings> Hash of settings; see below.

=back

The passed settings need to specify the output directory (C<outdir>) and the
L<Toolkit> template to use.

For example:

    my %settings = (
        'outfile' => 'generated/backlog.html',
        'template' => 'templates/backlog.templ',
        'toplocation' => 'web',
		'collect' => ['tags', 'series', 'who'],
    );
    my $backlog = Comic::Out::Backlog(%settings);

The C<template> defines the L<Toolkit> template to use.

The C<outfile> where the output should go.

The C<toplocation> will be the first element in the C<publishers> array made
available to the template, to move one publisher to the beginning of the
list, as a preferred one in ordering.

The C<collect> array says which per-language meta data to add to the backlog
overview.

=cut


sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new();

    %{$self->{settings}} = %settings;
    croak('Must specify Comic::Out::Backlog.template') unless ($self->{settings}->{template});
    croak('Must specify Comic::Out::Backlog.outfile') unless ($self->{settings}->{outfile});

	if ($self->{settings}->{collect}) {
		if (ref $self->{settings}->{collect} eq '') {
			# Turn into an array for easier use later.
			$self->{settings}->{collect} = [ $self->{settings}->{collect} ];
		}
		if (ref $self->{settings}->{collect} ne 'ARRAY') {
			croak('Comic::Out::Backlog.collect must be array or single value');
		}
	}
	else {
	    $self->{settings}->{collect} = [];
	}

    return $self;
}


=head2 generate_all

Generates the backlog page using the configured C<template> and writing the
results to the configured C<outfile>.

Parameters:

=over 4

=item * B<@comics> Comics to consider.

=back

See the user documentation for the variables defined for the template.

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my $page = $self->{settings}->{outfile};
    my $templ_file = $self->{settings}->{template};
    my %vars = $self->_populate_vars(@comics);
    Comic::write_file($page, Comic::Out::Template::templatize('Comic::Out::Backlog', $templ_file, '', %vars));

    return;
}


sub _populate_vars {
    my ($self, @comics) = @ARG;

    my @unpublished = sort Comic::from_oldest_to_latest grep {
         $_->not_yet_published()
    } @comics;

    my %languages;
    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $languages{$language} = 1;
        }
    }

    my @to_collect = @{$self->{settings}->{collect}};
    my %collected;
    # Manually set to empty hashes for easier use in the template.
    # Auto-vivification doesn't happen if we never enter the per-comic loop below.
    foreach my $want (@to_collect) {
        $collected{$want} = {};
    }

    foreach my $comic (@comics) {
        foreach my $want (@to_collect) {
            my $found = $comic->{meta_data}->{$want};
            next unless ($found);

            # Tag exists in meta data.
            foreach my $language ($comic->languages()) {
                my $per_language = $found->{$language};
				# Silently ignore empty tags. If a Check is configured, it may
                # or may not catch this.
                next unless ($per_language);

                if (ref $per_language eq '') {
                    # Single value, like series
                    $collected{$want}{"$per_language ($language)"}++;
                }
                elsif (ref $per_language eq 'ARRAY') {
                    # Multiple values, like tags
                    foreach my $got (@{$found->{$language}}) {
                        $collected{$want}{"$got ($language)"}++;
                    }
                }
                else {
                    croak("Comic::Out::Backlog: Cannot handle $want: must be array or single value, but got " . ref $per_language);
                }
            }
        }
    }

    my @languages = sort keys %languages;
    my %vars;
    $vars{'languages'} = \@languages;
    $vars{'comics'} = \@unpublished;
    $vars{'publishers'} = $self->_publishers(@comics);

    foreach my $want (@to_collect) {
		$vars{$want} = $collected{$want};
        ## no critic(BuiltinFunctions::ProhibitReverseSortBlock)
        # I need to sort by count first, then alphabetically by name, so I have to use
        # $b on the left side of the comparison operator. Perl Critic doesn't understand
        # my sorting needs...
		$vars{"${want}Order"} = [ sort {
            # First, sort by count
            $collected{$want}{$b} <=> $collected{$want}{$a} or
		# use critic
            # then by name, case insensitive, so that e.g., m and M get sorted together
            lc $a cmp lc $b or
            # then by name, case sensitive, to avoid names "jumping" around (and breaking tests).
            $a cmp $b
        } keys %{$collected{$want}} ];
	}

    return %vars;
}


sub _publishers {
    my ($self, @comics) = @ARG;

    my %unique_published = map {
        lc $_->{meta_data}->{published}->{where} => 1
    } @comics;

    my $top = $self->{settings}->{'toplocation'};
    if ($top) {
        my @published_without_top_location = grep { lc $_ ne lc $top } keys %unique_published;
        return [$top, sort {lc $a cmp lc $b} @published_without_top_location];
    }
    else {
        return [sort {lc $a cmp lc $b} keys %unique_published];
    }
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
