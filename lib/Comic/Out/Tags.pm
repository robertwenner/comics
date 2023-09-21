package Comic::Out::Tags;

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
        tags: {
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
    $self->flag_extra_settings();
    %{$self->{tags}} = ();
    %{$self->{tags_page}} = ();

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

    return if ($comic->not_yet_published());

    foreach my $language ($comic->languages()) {
        foreach my $tag (@{$self->{settings}{collect}}) {
            next unless $comic->{meta_data}{$tag};
            if (ref $comic->{meta_data}{$tag} ne 'HASH') {
                $comic->keel_over("$tag meta data must be a hash of languages to arrays of values");
            }
            next if (keys %{$comic->{meta_data}{$tag}} == 0);
            if (ref $comic->{meta_data}{$tag}{$language} ne 'ARRAY') {
                $comic->keel_over("$tag $language must be an array");
            }

            foreach my $collect (@{$comic->{meta_data}{$tag}{$language}}) {
                $self->{tags}{$language}{$collect}{$comic->{meta_data}{title}{$language}} = $comic->{href}{$language};
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

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    $self->_put_tags_in_comics(@comics);
    $self->_write_tags_pages(@comics);
    $self->_put_tags_pages_link_in_comics(@comics);
    return;
}


sub _put_tags_in_comics {
    my ($self, @comics) = @ARG;

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $comic->{tags}{$language} = {};
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
                        $comic->{tags}{$language}{$collect}{$title} = $self->{tags}{$language}{$collect}{$title};
                    }
                }
            }
        }
    }

    return;
}


sub _write_tags_pages {
    my ($self, @comics) = @ARG;

    # Can't write tag pages if there's no template configured.
    return unless (exists $self->{settings}->{template});

    foreach my $language (Comic::Out::Generator::all_languages(@comics)) {
        # We only write tags pages for published comics, so don't worry about backlogs.
        my $base_dir = $comics[0]->{settings}->{Paths}{'published'};
        my $tags_dir = $self->_get_outdir($language);
        my $full_dir = $base_dir . lc($language) . "/$tags_dir";
        Comic::make_dir($full_dir);

        my $template = $self->_get_template($language);

        foreach my $tag (keys %{$self->{tags}{$language}}) {
            my $tag_page = _sanitize($tag) . '.html';
            my %vars = (
                'language' => lc $language,
                'url' => "/$tags_dir/$tag_page",
                'tag' => $tag,
                'comics' => $self->{tags}{$language}{$tag},
                # Some template parts may need the root folder to reference
                # CSS or images. Provide it here for consistency and
                # compatibility with HtmlComicPage.
                # It can only be one level to www root, or earlier code
                # would have failed noisily trying to mkdir the path.
                'root' => '../',
            );
            my $page = Comic::Out::Template::templatize("$language $template", $template, $language, %vars);
            Comic::write_file("$full_dir/$tag_page", $page);
            $self->{tags_page}{$language}{$tag} = "$tags_dir/$tag_page";
        }
    }

    return;
}


sub _get_template {
    my ($self, $language) = @ARG;
    return $self->_get('template', $language);
}


sub _get_outdir {
    my ($self, $language) = @ARG;
    return $self->_get('outdir', $language);
}


sub _get {
    my ($self, $field, $language) = @_;

    my $thing;
    if (ref $self->{settings}->{$field} eq ref {}) {
        $thing = $self->{settings}->{$field}{$language};
    }
    else {
        $thing = $self->{settings}->{$field};
    }

    croak("no $field defined for $language") unless ($thing);
    return $thing;
}


sub _sanitize {
    # Remove non-alphanumeric characters to avoid problems in path names.
    my ($s) = @_;

    $s =~ s{\W+}{}g;

    return $s;
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
