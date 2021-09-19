package Comic::Out::HtmlComicPage;

use strict;
use warnings;
use utf8;
use Locales unicode => 1;
use English '-no_match_vars';
use Carp;
use Readonly;
use Clone qw(clone);

use Comic::Out::Template;
use Comic::Out::Generator;
use base('Comic::Out::Generator');


use version; our $VERSION = qv('0.0.3');


=for stopwords Wenner merchantability perlartistic notFor html outdir

=head1 NAME

Comic::Out::HtmlComicPage - Generates a html page for each comic, plus an
index page for the last.

=head1 SYNOPSIS

    my $html = Comic::Out::HtmlComicPage->new(\%settings);
    $html->generate_all(@comics);

=head1 DESCRIPTION

Generates an html page for a comic, using a Perl L<Template> Toolkit template.
Generates an F<index.html> page for the latest comic, using the same template,
at the parent of C<outdir>.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::HtmlComicPage.

Parameters:

=over 4

=item * B<$settings> Hash reference to settings.

=back

The passed settings need to have output directory (C<outdir>) and the
per-language templates for the comic pages (C<Settings>) and the domains
(per language).

For example:

    my $settings = {
        'Out' => {
            'Comic::Out::HtmlComicPage' => {
                'outdir' => 'generated',
                'Templates' => {
                    'English' => 'path/to/english/template',
                    'Deutsch' => 'path/to/german/template',
                },
            },
        },
    }
    my $hcp = Comic::Out::HtmlComicPage($settings);

The html page will be placed in the given C<outdir>. The file name is
derived from each Comic's title.

=cut

sub new {
    my ($class, $settings) = @ARG;
    my $self = $class->SUPER::new();

    croak('No Comic::Out::HtmlComicPage configuration') unless ($settings->{'Comic::Out::HtmlComicPage'});
    %{$self->{settings}} = %{$settings->{'Comic::Out::HtmlComicPage'}};

    croak('Must specify Comic::Out::HtmlComicPage.outdir output directory') unless ($self->{settings}->{outdir});
    $self->{settings}->{outdir} .= q{/} unless ($self->{settings}->{outdir} =~ m{/$});

    croak('Must specify Comic::Out::HtmlComicPage.Templates') unless ($self->{settings}->{Templates});

    return $self;
}


=head2 generate

Places HTML specific variables for the given comic in the given comic.

Parameters:

=over 4

=item * B<$comic> Comic to process.

=back

Defines these variables in the passed Comic:

=over 4

=item * B<%href> hash of language to its relative URL from the server root.

=item * B<%htmlFile> hash of language to the html file name (without path).

=back

=cut

sub generate {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->languages()) {
        $comic->{htmlFile}{$language} = "$comic->{baseName}{$language}.html";
        $comic->{href}{$language} = 'comics/' . $comic->{htmlFile}{$language};
    }
    return;
}


=head2 generate_all

Generates the html pages for the given Comics.

This is in C<generate_all> as it needs to know the first, previous, and next
comics for navigation links.

Parameters:

=over 4

=item * B<@comics> Comics for which to write a html pages.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my @sorted = sort Comic::from_oldest_to_latest @comics;
    foreach my $i (0 .. @sorted - 1) {
        my $comic = $sorted[$i];

        foreach my $language ($comic->languages()) {
            # This block links comics to their predecessor and successor
            my $first_comic = _find_next($language, $i, \@sorted, [0 .. $i - 1]);
            $comic->{'first'}{$language} = $first_comic ? $first_comic->{htmlFile}{$language} : 0;
            my $prev_comic = _find_next($language, $i, \@sorted, [reverse 0 .. $i - 1]);
            $comic->{'prev'}{$language} = $prev_comic ? $prev_comic->{htmlFile}{$language} : 0;
            my $next_comic = _find_next($language, $i, \@sorted, [$i + 1 .. @sorted - 1]);
            $comic->{'next'}{$language} = $next_comic ? $next_comic->{htmlFile}{$language} : 0;
            my $last_comic = _find_next($language, $i, \@sorted, [reverse $i + 1 .. @sorted - 1]);
            $comic->{'last'}{$language} = $last_comic ? $last_comic->{htmlFile}{$language} : 0;

            # Create dir(s)
            Comic::make_dir($self->{settings}->{outdir} . lc $language);

            # The actual export
            my %templates = %{$self->{settings}->{Templates}};
            my $template = $templates{$language};
            $comic->keel_over("Comic::Out::HtmlComicPage: No $language template") unless ($template);
            $self->_export_language_html($comic, $language, $template);
        }
    }

    # In addition to the regular comic pages, export an index.html page.
    $self->export_index(@comics);

    return;
}


sub _find_next {
    my ($language, $pos, $comics, $nums) = @ARG;

    foreach my $i (@{$nums}) {
        next if (@{$comics}[$i]->not_for($language));
        if (@{$comics}[$i]->not_yet_published() == @{$comics}[$pos]->not_yet_published()) {
            return @{$comics}[$i];
        }
    }

    return 0;
}


sub _export_language_html {
    # This could be inlined once tests don't call it directly anymore.
    my ($self, $comic, $language, $template) = @ARG;

    $comic->get_transcript($language);
    Comic::write_file("$comic->{dirName}{$language}/$comic->{htmlFile}{$language}",
        $self->_do_export_html($comic, $language, $template));
    return 0;

}


sub _do_export_html {
    my ($self, $comic, $language, $template) = @ARG;

    # Provide empty tags and who data, if the comic doesn't have that.
    # This avoids a crash in the template when it cannot access these.
    # This should probably be configurable, so that the template can check whether
    # tags or who exists, and print a header and footer only if this is the case.
    foreach my $what (qw(tags who)) {
        if (!defined $comic->{meta_data}->{who}->{$language}) {
            @{$comic->{meta_data}->{who}->{$language}} = ();
        }
    }

    my %vars;
    $vars{'comic'} = $comic;
    $vars{'languages'} = [grep { $_ ne $language } $comic->languages()];
    $vars{'languagecodes'} = { $comic->language_codes() };
    # Need clone the URLs so that there is no reference stored here, cause
    # later code may change these vars when creating index.html, but if
    # it's a reference, the actual URL values get changed, too, and that
    # leads to wrong links.
    $vars{'languageurls'} = clone($comic->{url});
    Readonly my $DIGITS_YEAR => 4;
    $vars{'year'} = substr $comic->{meta_data}->{published}->{when}, 0, $DIGITS_YEAR;
    $vars{'canonicalUrl'} = $comic->{url}{$language};

    # By default, use normal path with comics in comics/
    $vars{'comicsPath'} = 'comics/';
    $vars{'indexAdjust'} = '';
    my $path = '../';
    if ($comic->not_yet_published()) {
        # Adjust the path for backlog comics.
        $path = '../web/' . lc $language;
    }

    if ($comic->{isLatestPublished}) {
        # If this variable is set, we're called from export_index.
        # Adjust the path for top-level index.html: the comics are in their own
        # folder, but index.html is in that folder's parent folder.
        $path = '';
        $vars{'indexAdjust'} = $vars{'comicsPath'};
        foreach my $l (keys %{$vars{'languageurls'}}) {
            # On index.html, link to the other language's index.html, not to
            # the canonical URL of the comic. Google trips over that and thinks
            # there is no backlink.
            ${$vars{'languageurls'}}{$l} =~ s{^(https://[^/]+/).+}{$1};
        }
        # canonicalUrl is different for index.html (main url vs deep link)
        $vars{'canonicalUrl'} =~ s{^(https://[^/]+/).+}{$1};
    }

    if ($comic->not_yet_published()) {
        $vars{'root'} = "../$path/";
    }
    else {
        $vars{'root'} = $path;
    }

    return Comic::Out::Template::templatize($comic->{srcFile}, $template, $language, %vars);
}


=head2 export_index

Generates an C<index.html> page for the latest comic in each language.

The file will always be C<$outdir/<language>/index.html>, for example, for
English comics in C<$outdir/english/index.html>. The template file used is the
same as for all other comic pages.

Parameters:

=over 4

=item * B<@comics> all comics to look at to figure out the latest comic per
    language that should be the index.

=back

=cut

sub export_index {
    # What if index.html shouldn't use the same template as the other comic
    # pages? I guess I'll deal with that when I run into it.

    # Could I want different ways to generate index.html? A (symbolic) link?
    # Server and rsync may or may not support that. But that doesn't work
    # anyway cause URLs (to css, icons, or other comics) are different if
    # comics go in their own directory and index.html stays at top level (as
    # it should!).
    my ($self, @comics) = @ARG;

    my %templates = %{$self->{settings}->{Templates}};
    my %latest_published = $self->_find_latest_published(@comics);
    foreach my $language (sort keys %latest_published) {
        my $dir = $self->{settings}->{outdir} . lc $language;
        my $page = "$dir/index.html";
        my $last_pub = $latest_published{$language};
        my $html = $self->_do_export_html($last_pub, $language, $templates{$language});
        Comic::write_file($page, $html);
    }
    return;
}


=head2 _find_latest_published

Returns a hash of language to the latest published comic in that language.

Also sets the C<isLatestPublished> flag on the last published Comic(s), but
does not clear such a flag in other comics if it's already set.

The assumption about the C<isLatestPublished> is that programs that process
comics don't keep running and don't keep state, so no Comics initially have
C<isLatestPublished> set, and only the current ones get it set. That flag is
not written back to the comics on disk. Each run requires reading all comics
and finding the latest one anyway since we don't know when the last run was
and whether the C<isLatestPublished> state is still valid, which could
depend on date, comic schedule, and the comic collection --- all of which
could have changed since last run.

Parameters:

=over 4

=item * B<@comics> comics to consider.

=back

=cut

sub _find_latest_published {
    my ($self, @comics) = @ARG;

    my %latest_published;
    my %templates = %{$self->{settings}->{Templates}};
    foreach my $language (keys %templates) {
        my @sorted = (sort Comic::from_oldest_to_latest grep {
            !$_->not_yet_published($_) && $_->_is_for($language)
        } @comics);
        next if (@sorted == 0);

        my $last_pub = $sorted[-1];
        $last_pub->{isLatestPublished} = 1;
        $latest_published{$language} = $last_pub;
    }
    return %latest_published;
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
