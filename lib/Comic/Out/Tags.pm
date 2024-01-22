package Comic::Out::Tags;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use File::Path;
use File::Slurper;

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Generator;
use base('Comic::Out::Generator');
use Comic::Out::Template;


=encoding utf8

=for stopwords Wenner merchantability perlartistic outdir html


=head1 NAME

Comic::Out::Tags - Collects tags from comics to provide tagging in comic pages.


=head1 SYNOPSIS

    my $feed = Comic::Out::Tags->new(%settings);
    $feed->generate($comic);
    $feed->generate_all(@comics);


=head1 DESCRIPTION

Collects tags from all comics and allows comics to link to other comics that
share the same tags.

Tags are case-sensitive, i.e., a comic tagged "Beer" will not refer to one
tagged "beer".

These kinds of comics are ignored for tag processing:

=over 4

=item B<*> Untitled comics (they are not considered to have any languages).

=item B<*> Comics that are not yet published.

=item B<*> Comics that are not published on the web.

=back

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Tags.

Parameters are taken from the C<Out.Tags> configuration:

=over 4

=item * B<$settings> Settings hash.

=back

The passed settings can have:

=over 4

=item * B<@collect> array of metadata tag names to collect. In the comics,
    these must be found as hashes of languages to arrays of the actual tags,
    as top-level attributes in the comic's metadata.

For the `collect` argument, the this example comic metadata:

    'meta_data' => {
        'tags': {
            'English' => ['some value', 'other value'],
        },
    }

Passing "tags" for the "collect" parameter will pick the example values above.

=item * B<template> Either a scalar with the Toolkit template path /
    filename, or a hash of languages to template files.
    If this is not given, no template pages will be generated.

=item * B<outdir> Either a scalar to use one folder name for all
    languages (but in different per-languages directories) or hash of
    language to output folder. This module will place a html file for each
    tag with links to other comics with this tag into that folder.
    This must be a single folder name, not a path. Defaults to "tags".

=item * B<$min-count> Specifies the minimum occurrences a tag must
    have to be considered for pages and in-comic. Defaults to 0. If a tag
    has less than the given number of uses, it doesn't get a tag page and
    won't be placed into comics for linking.

=back

When writing tag pages, the template can use these variables:

=over 4

=item * B<root> points to the server root, e.g., "../".

=item * B<tag> The actual tag for the page.

=item * B<language> Current language, e.g., "english".

=back

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->optional('collect', 'array-or-scalar', ['tags']);
    $self->optional('template', 'hash-or-scalar');
    $self->optional('outdir', 'hash-or-scalar', 'tags');
    $self->optional('min-count', 'scalar', 0);
    unless ($self->{settings}->{'min-count'} =~ m{^\d+$}x) {
        croak('min-count must be a positive number');
    }
    $self->optional('index', 'hash-or-scalar');
    if ($self->{settings}->{index} && !exists $self->{settings}->{template}) {
        croak('must specify Comic::Out::Tag.template when specifying index template');
    }
    $self->flag_extra_settings();

    %{$self->{tags}} = ();  # tag per language to comic href
    %{$self->{tags_page}} = ();  # tags page url
    %{$self->{tag_page_names}} = ();  # used tag page names, to avoid collisions
    %{$self->{tag_count}} = ();  # counts per tag per language
    %{$self->{tag_rank}} = ();  # tag name to CSS style indicating ranking (1 - 5)
    %{$self->{last_modified}} = ();  # last modified date for tag per language

    return $self;
}


=head2 generate

Collects the tags from the given Comic.

Parameters:

=over 4

=item * B<$comic> Comic to process.

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    return unless ($comic);
    return if ($comic->not_yet_published());

    foreach my $language ($comic->languages()) {
        foreach my $tag (@{$self->{settings}{collect}}) {
            unless ($comic->{meta_data}{$tag}) {
                $comic->warning("Doesn't have $tag");
                next;
            }

            if (ref $comic->{meta_data}{$tag} ne 'HASH') {
                $comic->warning("$tag meta data must be a hash of languages to arrays of values");
                next;
            }
            next if (keys %{$comic->{meta_data}{$tag}} == 0);
            if (ref $comic->{meta_data}{$tag}{$language} ne 'ARRAY') {
                $comic->warning("$tag $language must be an array");
                next;
            }

            foreach my $collect (@{$comic->{meta_data}{$tag}{$language}}) {
                # warn about empty (e.g., "") tags, probably a typo or missed template
                $comic->warning("Empty value in $tag found") if ($collect =~ m{^\s*$}x);

                $self->{tags}{$language}{$collect}{$comic->{meta_data}{title}{$language}} = $comic->{href}{$language};
                $self->{tag_count}{$language}{$collect}++;
                if (($self->{last_modified}{$language}{$collect} || q{0}) lt $comic->{modified}) {
                    $self->{last_modified}{$language}{$collect} = $comic->{modified};
                }
            }
        }
    }

    return;
}


=head2 generate_all

Writes the collected tags to each of the passed comics.

Generates a web page for each tag using the passed template.

Parameters:

=over 4

=item * B<@comics> Comics to process.

=back

Defines these variables in each passed Comic:

=over 4

=item * B<%tags> A hash of languages to hashes of comic titles to relative
    comic URLs (C<href>). The comic template can turn those into links
    to the other comics that use the same tags.
    There will be no link to the current comic, i.e., no comic will refer to
    itself. (This is checked by comparing the Comic's titles).

=item * B<%tags_page> A hash of languages to a hash of tags pointing to the
    generated tags pages. The comic page template can use these to link to
    the tags pages.

=item * B<%tag_count> A hash of tag to the number it was used, per language.

=item * B<%min> lowest tag use, per language.

=item * B<%max> highest tag use, per language.

=item * B<%all_tags_pages> Hash of language to hash of tag to tag page. As
    opposed to C<%tags> and C<%tags_pages> this includes all tags seen. It can
    be used for a tag cloud, not only the ones the current comic uses.

=back

Makes these variables available to the tag page template:

=over 4

=item * B<$language> Name of the language for which the tag is, e.g., English.

=item * B<$url> URL of the tag page relative to the server root.

=item * B<$root> Relative offset to the server root.

=item * B<%comics> Hash of comic URL to comic title, of all comics that use
    the current tag in the given language.

=item * B<$last_modified> ISO 8601 date of the latest comic that uses a tag.

=item * B>$count> How often this tag was used.

=item * B<%all_tags_pages> Hash of language to hash of tag to tag page.
    Intended for a tag cloud.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    $self->_find_min_and_max(@comics);
    $self->_put_tags_in_comics(@comics);
    $self->_put_tag_style_ranks_in_comics(@comics);
    $self->_write_tags_pages(@comics);
    $self->_write_index_tags_page(@comics);
    $self->_put_tags_pages_link_in_comics(@comics);
    return;
}


sub _find_min_and_max {
    my ($self, @comics) = @ARG;

    foreach my $language (keys %{$self->{tags}}) {
        my $min;
        my $max;
        foreach my $tag (keys %{$self->{tag_count}{$language}}) {
            my $uses = $self->{tag_count}{$language}{$tag};
            $min = $uses if (!defined $min || $uses < $min);
            $max = $uses if (!defined $max || $uses > $max);
        }
        $self->{min}{$language} = $min;
        $self->{max}{$language} = $max;
    }

    return;
}


sub _put_tags_in_comics {
    my ($self, @comics) = @ARG;

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $comic->{tags}{$language} = {};
            $comic->{tag_count}{$language} = {};
            # Unpublished comics could link to others, but then the code here
            # would need to know about backlog vs published paths. A comic that's
            # not (yet) published on the web must never be included in a published
            # comic's tags.
            # Check here to that comics get at least an empty hash for easier use
            # in templates.
            next if ($comic->not_yet_published());

            foreach my $tag (@{$self->{settings}{collect}}) {
                foreach my $collect (@{$comic->{meta_data}{$tag}{$language}}) {
                    foreach my $title (keys %{$self->{tags}{$language}{$collect}}) {
                        # Don't link-tag to self.
                        next if ($comic->{meta_data}->{title}{$language} eq $title);
                        # Honor minimum tags count.
                        my $tag_count = $self->{tag_count}{$language}{$collect};
                        next if ($tag_count < $self->{settings}->{'min-count'});

                        $comic->{tags}{$language}{$collect}{$title} = $self->{tags}{$language}{$collect}{$title};
                        $comic->{tag_count}{$language}{$collect} = $self->{tag_count}{$language}{$collect};
                    }
                }
            }

            $comic->{tag_min}{$language} = $self->{min}{$language};
            $comic->{tag_max}{$language} = $self->{max}{$language};
        }
    }

    return;
}


sub _put_tag_style_ranks_in_comics {
    my ($self, @comics) = @ARG;

    return unless (%{$self->{tags}});

    # From https://en.wikipedia.org/wiki/Tag_cloud:
    #       relevance = (current tag - tag min) / (tag max - tag min)
    # Yields a div/0 error if there's only 1 tag, or a number between 0
    # (least used token) and 1 (most used token).
    #
    # Examples:
    # 1, 5 --> 0, 1
    # 1, 3, 5 --> 0, 0.5, 1
    # 1, 2, 3, 4, 5 --> 0, 0.2, 0.5, 0.75, 1
    # 1, 5, 10, 20 --> 0, 0.21, 0.47, 1
    # 1, 5, 7, 9, 13, 20 --> 0, 0.21, 0.31, 0.42, 0.63, 1
    #
    # Box this up in 5 categories / buckets as: <= 0.2, 0.4, 0.6, 0.8, 1

    foreach my $language (Comic::Out::Generator::all_languages(@comics)) {
        my $range = $self->{max}{$language} - $self->{min}{$language};

        foreach my $tag (keys %{$self->{tags}{$language}}) {
            my $tag_count = $self->{tag_count}{$language}{$tag};
            next if ($tag_count < $self->{settings}->{'min-count'});

            my $relevance;
            if ($range == 0) {
                # The only tag is certainly most important. And this avoids
                # a division by zero.
                $relevance = 1;
            }
            else {
                $relevance = ($tag_count - $self->{min}{$language}) / $range;
            }

            $self->{tag_rank}{$language}{$tag} = 'taglevel' . _bucket($relevance);
        }
    }

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $comic->{tag_rank}{$language} = $self->{tag_rank}{$language};
        }
    }

    return;
}


sub _bucket {
    my $fraction = shift;

    ## no critic(ValuesAndExpressions::ProhibitMagicNumbers)
    my @bucket_max = (0.2, 0.4, 0.6, 0.8);
    ## use critic
    my $bucket = 0;
    while ($bucket < @bucket_max) {
        return $bucket + 1 if ($fraction < $bucket_max[$bucket]);
        $bucket++;
    }
    return @bucket_max + 1;
}


sub _write_tags_pages {
    my ($self, @comics) = @ARG;

    # Can't write tag pages if there's no template configured.
    return unless (exists $self->{settings}->{template});

    foreach my $language (Comic::Out::Generator::all_languages(@comics)) {
        # Reserve index.html
        $self->{tag_page_names}->{$language}->{'index'} = 1;

        # We only write tags pages for published comics, so don't worry about backlogs.
        my $base_dir = $comics[0]->{settings}->{Paths}{'published'};
        my $tags_dir = $self->get_setting('outdir', $language);
        my $full_dir = $base_dir . lc($language) . "/$tags_dir";
        File::Path::make_path($full_dir);

        my $template = $self->get_setting('template', $language);

        # sort keys to have a stable order when non-unique tags are made unique.
        # This helps with testing and doesn't break bookmarks to tags pages.
        # (Bookmarks may point to different tags pages when min-count changes, though.)
        foreach my $tag (sort keys %{$self->{tags}{$language}}) {
            my $tag_count = $self->{tag_count}{$language}{$tag};
            next if ($tag_count < $self->{settings}->{'min-count'});

            my $tag_page = $self->_unique($language, Comic::Out::Generator::sanitize($tag)) . '.html';
            my %vars = (
                'Language' => $language,
                'url' => "/$tags_dir/$tag_page",
                'tag' => $tag,
                'comics' => $self->{tags}{$language}{$tag},
                'last_modified' => $self->{last_modified}{$language}{$tag},
                'count' => $tag_count,
                'min' => $self->{min}{$language},
                'max' => $self->{max}{$language},
                # Some template parts may need the root folder to reference
                # CSS or images. Provide it here for consistency and
                # compatibility with HtmlComicPage.
                # It can only be one level to www root, or earlier code
                # would have failed noisily trying to mkdir the path.
                'root' => '../',
            );
            my $page = Comic::Out::Template::templatize("$language $template", $template, $language, %vars);
            File::Slurper::write_text("$full_dir/$tag_page", $page);
            $self->{tags_page}{$language}{$tag} = "$tags_dir/$tag_page";
        }
    }

    return;
}


sub _write_index_tags_page() {
    my ($self, @comics) = @_;

    return unless (exists $self->{settings}->{index});

    foreach my $language (Comic::Out::Generator::all_languages(@comics)) {
        my $base_dir = $comics[0]->{settings}->{Paths}{'published'};
        my $tags_dir = $self->get_setting('outdir', $language);
        my $full_dir = $base_dir . lc($language) . "/$tags_dir";
        File::Path::make_path($full_dir);
        my $tag_page = 'index.html';

        my $last_modified = 0;
        foreach my $tag (keys %{$self->{last_modified}{$language}}) {
            if ($last_modified lt $self->{last_modified}{$language}{$tag}) {
                $last_modified = $self->{last_modified}{$language}{$tag};
            }
        }

        my $template = $self->get_setting('index', $language);
        $self->{tag_rank}->{$language} ||= {};
        my %vars = (
            'language' => lc $language,
            'url' => "/$tags_dir/$tag_page",
            'min' => $self->{min}{$language},
            'max' => $self->{max}{$language},
            'last_modified' => $last_modified,
            # Some template parts may need the root folder to reference
            # CSS or images. Provide it here for consistency and
            # compatibility with HtmlComicPage.
            # It can only be one level to www root, or earlier code
            # would have failed noisily trying to mkdir the path.
            'root' => '../',
            'tags_page' => $self->{tags_page},
            'tag_rank' => $self->{tag_rank},
            'tag_count' => $self->{tag_count},
        );
        my $page = Comic::Out::Template::templatize("$language $template", $template, $language, %vars);
        File::Slurper::write_text("$full_dir/$tag_page", $page);
    }

    return;
}


sub _unique {
    my ($self, $language, $sanitized_tag) = @ARG;

    my $name = $sanitized_tag;
    my $count = 0;
    while (defined $self->{tag_page_names}->{$language}->{$name}) {
        $name = "${sanitized_tag}_$count";
        $count++;
    }
    $self->{tag_page_names}->{$language}->{$name} = 1;

    return $name;
}


sub _put_tags_pages_link_in_comics {
    my ($self, @comics) = @ARG;

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            # Make sure there's at least an empty hash, so that Template
            # Toolkit can check that the variable is defined and has tags.
            # If nothing's defined, a page template could trip over this.
            $comic->{tags_page}{$language} = {};

            foreach my $tag (@{$self->{settings}{collect}}) {
                foreach my $collect (@{$comic->{meta_data}{$tag}{$language}}) {
                    # Skip comics where the tag doesn't exist elsewhere. This can happen if
                    # all (other) comics for that tag are unpublished, for example.
                    if ($self->{tags_page}{$language}{$collect}) {
                        $comic->{tags_page}{$language}{$collect} = $self->{tags_page}{$language}{$collect};
                    }
                }
            }

            $comic->{all_tags_pages}{$language} = $self->{tags_page}{$language};
        }
    }

    return;
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
