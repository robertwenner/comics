package Comic::Out::Series;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Generator;
use base('Comic::Out::Generator');
use Comic::Out::Template;


=encoding utf8

=for stopwords Wenner merchantability perlartistic outdir html prev


=head1 NAME

Comic::Out::Series - Generate per-series hyperlinks between html comics.


=head1 SYNOPSIS

    my $feed = Comic::Out::Series->new(%settings);
    $feed->generate($comic);
    $feed->generate_all(@comics);


=head1 DESCRIPTION

Collects series from all comics' metadata and links comics to other comics
in that series.

A series is an ordered (by date) list of comics, where the story arch
progresses from earlier to later comics. This is different from tags, where
order of the comics does not matter; all comics with a tag are somehow related.

Each comic can belong to only one series.

Series are case-sensitive, i.e., a comic in the "Beer" series will not refer to one
in the "beer" series.

Comics that are not (yet) published on the web are ignored.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Series.

Parameters are taken from the C<Out.Series> configuration:

=over 4

=item * B<$settings> Settings hash.

=back

The passed settings can have:

=over 4

=item * B<$series> name of the metadata element to collect. Defaults to "series".

The C<series> needs to appear in the comic metadata as an object of language
to series title:

    'meta_data' => {
        'series': {
            'English' => 'brewing beer',
        },
    }

=item * B<collect> the name of the series tag you want to collect from each comic.
    Defaults to "series". With that, each comic needs to have the metadata as shown
    in the snippet above. The same C<collect> is used for all languages.

=item * B<template> either a single file name or a hash of languages to file
    names for the Toolkit template to use for a series page. No series page will
    be generated if this is not given.

=item * B<outdir> Either a scalar to use one folder name for all
    languages (but in different per-languages directories) or hash of
    language to output folder. This module will place a html file for each
    series with links to the comics in that series in that folder.
    This must be a single folder name, not a path. Defaults to "series".

=item * B<min-count> Minimum number of times a series has to be seen to actually
    generate anything for it. This can be used to suppress single comic series,
    i.e., when there's only one comic (yet), it makes no sense to show series navigation
    buttons or have a series page for it. Defaults to 2.

=item * B<index> Path to a Toolkit template file to use when generating the series
    index page.

=back

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->optional('collect', 'scalar', 'series');
    $self->optional('template', 'hash-or-scalar');
    $self->optional('outdir', 'hash-or-scalar', 'series');
    $self->optional('min-count', 'scalar', 2);
    unless ($self->{settings}->{'min-count'} =~ m{^\d+$}x) {
        croak('Comic::Out::Series.min-count must be a positive number');
    }
    $self->optional('index', 'hash-or-scalar');
    if ($self->{settings}->{index} && !exists $self->{settings}->{template}) {
        croak('must specify Comic::Out::Series.template when specifying index template');
    }
    $self->flag_extra_settings();

    %{$self->{titles_and_hrefs}} = ();  # language to array of anonymous hashes of title and href
    %{$self->{last_modified}} = ();  # last modified date for series per language
    %{$self->{series_page}} = ();  # language to series to series page
    %{$self->{series_page_names}} = ();     # for unique names
    $self->{seen} = 0;      # count how often we've seen series meta data

    return $self;
}


=head2 generate

Collects the series from the given Comic.

Parameters:

=over 4

=item * B<$comic> Comic to process.

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    my $me = ref $self;
    my $collect = $self->{settings}->{collect};
    my $series_for_all_languages = $comic->{meta_data}->{$collect};
    return unless (defined $series_for_all_languages);

    if (ref $series_for_all_languages ne ref {}) {
        $comic->warning("$me: $collect metadata must be a map of language to series title");
        return;
    }

    foreach my $language ($comic->languages()) {
        # Ignore a comic that doesn't have series in the metadata; not all comics belong
        # to a series.
        my $series = $series_for_all_languages->{$language};
        next unless (defined $series);

        if (ref $series ne '') {
            $comic->warning("$me: $language $collect metadata per language must be a single value");
            next;
        }
        if ($series =~ m/^\s*$/) {
            $comic->warning("$me: $language $collect is empty; ignored");
            next;
        }

        $self->{seen}++;
        next if ($comic->not_yet_published());

        my $title_and_href = {
            'title' => $comic->{meta_data}->{title}->{$language},
            'href' => $comic->{href}->{$language},
            'published' => $comic->_published_when(),
        };
        push @{$self->{titles_and_hrefs}->{$language}->{$series}}, $title_and_href;

        if (($self->{last_modified}{$language}{$series} || q{0}) lt $comic->{modified}) {
            $self->{last_modified}{$language}{$series} = $comic->{modified};
        }
    }

    return;
}


=head2 generate_all

Writes the collected series links to each of the passed comics in the same series.

Generates a web page for each series using the passed template.

Parameters:

=over 4

=item * B<@comics> Comics to process.

=back

Defines these variables in each passed Comic:

=over 4

=item * B<%series> hash of the keys first, prev, next, and last to the first,
    previous, next, and last comic in the series. The first comic won't have
    prev and first; and the last won't have next and last.
    This is always called C<series>, independent of the C<collect> configuration.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;
    $self->_check_series_exists();
    $self->_generate_nav_links(@comics);
    $self->_generate_series_pages(@comics);
    $self->_generate_index_page(@comics);
    $self->_put_series_pages_link_in_comics(@comics);
    return;
}


sub _check_series_exists {
    my ($self) = @ARG;

    my $me = ref $self;
    croak("$me: no comics had the '$self->{settings}->{collect}' metadata; typo?") unless ($self->{seen});
    return;
}


sub _generate_nav_links {
    my ($self, @comics) = @ARG;

    my $collect = $self->{settings}->{collect};
    foreach my $comic (@comics) {
        my $series_for_all_languages = $comic->{meta_data}->{$collect};

        foreach my $language ($comic->languages()) {
            # Define an empty hash for easy use in templates.
            $comic->{series}->{$language} = {};
            next unless (defined $series_for_all_languages);

            my $series = $comic->{meta_data}->{$collect}->{$language};
            # Ignore comics that aren't part of a series.
            next unless ($series);
            next unless ($self->{titles_and_hrefs}->{$language}->{$series});

            $self->{seen}++;

            my @titles_and_hrefs = sort _by_published_date @{$self->{titles_and_hrefs}->{$language}->{$series}};
            my ($pos) = grep {
                $titles_and_hrefs[$_]->{href} eq $comic->{href}->{$language}
            } 0 .. $#titles_and_hrefs;
            if (!defined $pos) {
                # Comic not found in the list of its series: This happens when the
                # current comic is not yet published, but others in the series are.
                # Add series links as good as we can, for a realistic preview in the
                # backlog.
                # First link is easy (first in series). Assume the current last will
                # be the previous for this comic. If there are multiple unpublished
                # comics in the series, they are all considered the last ones.
                $comic->{series}->{$language}->{'first'} = $titles_and_hrefs[0]->{href};
                $comic->{series}->{$language}->{'prev'} = $titles_and_hrefs[-1]->{href};
            }
            else {
                if ($pos > 0) {
                    $comic->{series}->{$language}->{'first'} = $titles_and_hrefs[0]->{href};
                    $comic->{series}->{$language}->{'prev'} = $titles_and_hrefs[$pos - 1]->{href};
                }
                if ($pos < $#titles_and_hrefs) {
                    $comic->{series}->{$language}->{'next'} = $titles_and_hrefs[$pos + 1]->{href};
                    $comic->{series}->{$language}->{'last'} = $titles_and_hrefs[-1]->{href};
                }
            }
        }
    }

    return;
}


sub _by_published_date {
    return $a->{published} cmp $b->{published};
}


sub _generate_series_pages {
    my ($self, @comics) = @ARG;

    return unless ($self->{settings}->{template});

    foreach my $language (Comic::Out::Generator::all_languages(@comics)) {
        # Reserve index.html
        $self->{series_page_names}->{$language}->{'index'} = 1;

        my $base_dir = $comics[0]->{settings}->{Paths}{'published'};
        my $series_dir = $self->get_setting('outdir', $language);
        my $full_dir = $base_dir . lc($language) . "/$series_dir";
        File::Path::make_path($full_dir);

        my $template = $self->get_setting('template', $language);

        foreach my $series (sort keys %{$self->{titles_and_hrefs}->{$language}}) {
            my @titles_and_hrefs = sort _by_published_date @{$self->{titles_and_hrefs}->{$language}->{$series}};
            next if (@titles_and_hrefs < $self->{settings}->{'min-count'});

            my $series_page = $self->_unique($language, Comic::Out::Generator::sanitize($series)) . '.html';
            my %vars = (
                'Language' => $language,
                'url' => "/$series_dir/$series_page",
                'series' => $series,
                'comics' => \@titles_and_hrefs,
                'last_modified' => $self->{last_modified}{$language}{$series},
                # Some template parts may need the root folder to reference
                # CSS or images. Provide it here for consistency and
                # compatibility with HtmlComicPage.
                # It can only be one level to www root, or earlier code
                # would have failed noisily trying to mkdir the path.
                'root' => '../',
            );
            my $page = Comic::Out::Template::templatize("$language $template", $template, $language, %vars);
            Comic::write_file("$full_dir/$series_page", $page);
            $self->{series_page}->{$language}->{$series} = "$series_dir/$series_page";
        }
    }

    return;
}


sub _put_series_pages_link_in_comics {
    my ($self, @comics) = @ARG;

    my $collect = $self->{settings}->{collect};
    foreach my $comic (@comics) {
        my $series_for_all_languages = $comic->{meta_data}->{$collect};

        foreach my $language ($comic->languages()) {
            $comic->{series_page}->{$language} = {};
            next unless (defined $series_for_all_languages);

            my $series = $comic->{meta_data}->{$collect}->{$language};
            # Ignore comics that aren't part of a series.
            next unless ($series);
            next unless ($self->{series_page}->{$language}->{$series});

            $comic->{series_page}->{$language}->{$series} = $self->{series_page}->{$language}->{$series};
        }
    }

    return;
}


sub _generate_index_page {
    my ($self, @comics) = @ARG;

    return unless (exists $self->{settings}->{index});

    foreach my $language (Comic::Out::Generator::all_languages(@comics)) {
        my $base_dir = $comics[0]->{settings}->{Paths}{'published'};
        my $series_dir = $self->get_setting('outdir', $language);
        my $full_dir = $base_dir . lc($language) . "/$series_dir";
        File::Path::make_path($full_dir);
        my $index_page = 'index.html';

        my $last_modified = 0;
        foreach my $series(keys %{$self->{last_modified}{$language}}) {
            if ($last_modified lt $self->{last_modified}{$language}{$series}) {
                $last_modified = $self->{last_modified}{$language}{$series};
            }
        }

        my $template = $self->get_setting('index', $language);
        # $self->{series_pages}->{$language} is a hash of series name to series page
        # and hashes are unordered per definition, so transform into an array of tuples.
        my @series_pages;
        my @titles = sort _case_insensitive keys %{$self->{series_page}->{$language}};
        foreach my $title (@titles) {
            push @series_pages, {
                'title' => $title,
                'href' => $self->{series_page}->{$language}->{$title},
            };
        }
        my %vars = (
            'language' => lc $language,
            'url' => "/$series_dir/$index_page",
            'last_modified' => $last_modified,
            # Some template parts may need the root folder to reference CSS or
            # images. Provide it here for consistency and compatibility with
            # HtmlComicPage.
            'root' => '../',
            'series_pages' => \@series_pages,
        );
        my $page = Comic::Out::Template::templatize("$language $template", $template, $language, %vars);
        Comic::write_file("$full_dir/$index_page", $page);
    }

    return;
}


sub _case_insensitive {
    return lc $a cmp lc $b;
}


sub _unique {
    my ($self, $language, $sanitized_tag) = @ARG;

    my $name = $sanitized_tag;
    my $count = 0;
    while (defined $self->{series_page_names}->{$language}->{$name}) {
        $name = "${sanitized_tag}_$count";
        $count++;
    }
    $self->{series_page_names}->{$language}->{$name} = 1;

    return $name;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

Comic metadata, the Comic modules.


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

Copyright (c) 2023, Robert Wenner C<< <rwenner@cpan.org> >>.
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
