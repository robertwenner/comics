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


=encoding utf8

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
L<Template::Toolkit> template to use.

For example:

    my %settings = (
        'outfile' => 'generated/backlog.html',
        'template' => 'templates/backlog.templ',
        'toplocation' => 'web',
        'collect' => ['tags', 'series', 'who'],
    );
    my $backlog = Comic::Out::Backlog(%settings);

The C<template> defines the L<Template::Toolkit> template to use.

The C<outfile> where the output should go.

The C<toplocation> will be the first element in the C<publishers> array made
available to the template, to move one publisher to the beginning of the
list, as a preferred one in ordering.

The C<collect> array says which per-language meta data to add to the backlog
overview.

=cut


sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->needs('template', 'scalar');
    $self->needs('outfile', 'scalar');
    $self->optional('toplocation', 'scalar', undef);
    $self->optional('collect', 'array-or-scalar', []);
    $self->flag_extra_settings();

    return $self;
}


=head2 generate_all

Generates the backlog page using the configured C<template> and writing the
results to the configured C<outfile>.

Parameters:

=over 4

=item * B<@comics> Comics to consider.

=back

Makes these variables available in the template:

=over 4

=item * B<@comics> array of all unpublished comics in all languages, sorted
    from sooner to later scheduled.

=item * B<@languages> all languages that have at least 1 comic (published or
    not); with first letter in upper case and the rest in lower case, e.g.,
    "English".

=item * B<@publishers> Array for published locations, taken from the
    C<published.where> comic metadata. Any configured C<toplocation> will go
    first, entries after that will be in alphabetical order.

=item * for each of the configured C<collect> items: a hash of collected
    values to the number of occurrences. For example, if "tags" was
    collected, the template can access a C<tagsOrder> array (sorted by
    frequency, then by found tag name) and a C<tags> hash of keyword to
    count, e.g., tag "beer" was seen 5 times. Having the array for sorting
    is a workaround for Perl hashes not having a defined order. (This should
    probably be replaced with a tied hash.)

=back

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
    my @published = reverse sort Comic::from_oldest_to_latest grep {
        not $_->not_yet_published();
    } @comics;

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

    my %vars;
    $vars{'languages'} = [Comic::Out::Generator::all_languages(@comics)];
    $vars{'unpublished_comics'} = \@unpublished;
    $vars{'published_comics'} = \@published;
    $vars{'publishers'} = $self->_publishers(@comics);

    foreach my $want (@to_collect) {
        $vars{$want} = $collected{$want};
        $vars{"${want}Order"} = [
            # Perl::Critic complains that this sort block is too long, and I'd
            # agree, but I don't see how I can move it to its own sub since it
            # needs %collected.
            ## no critic(BuiltinFunctions::RequireSimpleSortBlock)
            # I'm using the long form with multiple if blocks as Devel::Cover
            # complained about uncovered branches and conditions with a set of
            # cmp or <=> operators; https://stackoverflow.com/questions/69848068
            # I need to sort by count first, so I have to use $b on the left
            # side of the comparison operator. Perl Critic doesn't
            # understand my sorting needs...
            ## no critic(BuiltinFunctions::ProhibitReverseSortBlock)
            sort {
                my $cmp = $collected{$want}{$b} <=> $collected{$want}{$a};
                ## use critic
                if (!$cmp) {
                    # Then sort by name, case insensitive, so that e.g., m and M
                    # get sorted together (Branch true cannot be covered: cmp
                    # always returns non-zero cause we only have each term only
                    # once as a hash key.)
                    $cmp = lc $a cmp lc $b; # uncoverable branch true

                }
                if (!$cmp) {
                    # Lastly sort by name, case sensitive, to avoid names
                    # "jumping" around (and breaking tests).
                    $cmp = $a cmp $b;
                }
                $cmp;
            } keys %{$collected{$want}},
        ];
    }

    return %vars;
}


sub _publishers {
    my ($self, @comics) = @ARG;

    # Try to preserve case of locations, but if they differ only in case,
    # consider them equal. Keep the first case of any location.
    # Could probably also use Hash::Case::Preserve for this, but I'm trying
    # to avoid pulling in too many modules that trip up CI when dependencies
    # are missing.
    my %lower_location;
    my %unique_published;
    foreach my $comic (@comics) {
        my $where = $comic->{meta_data}->{published}->{where} || '';
        my $key = $lower_location{lc $where} || $where;
        $unique_published{$key}++;
        $lower_location{lc $where} = $where unless ($lower_location{lc $where});
    }

    my $top = $self->{settings}->{'toplocation'};
    if ($top) {
        my @published_without_top_location = grep { $_ ne $top } keys %unique_published;
        return [$top, sort @published_without_top_location];
    }
    else {
        return [sort keys %unique_published];
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
