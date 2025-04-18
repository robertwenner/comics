package Comic::Out::HtmlLink;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Generator;
use base('Comic::Out::Generator');


=encoding utf8

=for stopwords Wenner merchantability perlartistic svg html metadata url


=head1 NAME

Comic::Out::HtmlLink - Generates a reference ("see that other comic") from
comic metadata.


=head1 SYNOPSIS

    my $htmllink = Comic::Out::HtmlLink->new();
    $htmllink->generate_all(@comics);


=head1 DESCRIPTION

Generates links to other of your comics that can be used in HTML.

If you want to add any link, just put it in the comic and have your template
handle it.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::HtmlLink.

The constructor takes no arguments.

Actual linking is triggered by comic metadata within a C<see> object. This
is language specific, so it needs a nested language object with a link text
as key and a svg file as value.

    "see": {
        "English": {
            "First reopening": "comics/web/beergarden-reopened.svg"
        }
    }

Link targets are given as svg source file names so that a referrer does not
depend on the actual title (and hence URL) of the linked comic.
Also, other forms of linking (e.g., to a page in a book) may not even have
metadata like an html output file, but all comics do have a title.

Links are per-language cause the link text varies by language.

=cut


sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    $self->flag_extra_settings();
    return $self;
}


=head2 generate_all

Generates the references in all comics that want them.

Parameters:

=over 4

=item * B<@comics> All Comics to consider.

=back

Makes these variables available in the template:

=over 4

=item * B<%htmllink> A hash of language to a hash of link text to the link
target (url).

For example:

    {
        "htmllink" => {
            "English" => {
                "link text" => "URL of link target"
            }
        }
    }

The link text is not HTML escaped, the template should do this.

The link target should be URL-encoded, but this module only copies what the
Comic already has for an URL, so it's up to the module that creates URLs to
make sure they are valid. Along those lines, it's also up to that code
whether the URL is absolute (probably).

If a Comic does not refer to others, this module won't add the C<htmllink>
at all. Templates can check its existence to decide whether to print a
prologue, then iterate over the languages and within the languages over the
link text / link target pairs.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $comic->{'htmllink'}{$language} = {};
            if (!defined $comic->{meta_data}->{see} || !defined $comic->{meta_data}->{see}{$language}) {
                next;
            }

            my $references = $comic->{meta_data}->{see}{$language};
            REF: foreach my $ref (keys %{$references}) {
                my $want = ${$references}{$ref};

                # Try exact match.
                foreach my $c (@comics) {
                    if ($c->{srcFile} eq $want) {
                        $comic->{'htmllink'}{$language}{$ref} = $c->{htmlFile}{$language};
                        next REF;
                    }
                }

                # Try relative match: if the path ends in what we're looking for.
                my @found;
                foreach my $c (@comics) {
                    if ($c->{srcFile} =~ m{$want$}) {
                        $comic->{'htmllink'}{$language}{$ref} = $c->{htmlFile}{$language};
                        push @found, $c->{srcFile};
                    }
                }
                if (@found > 1) {
                    $comic->keel_over("Comic::Out::HtmlLink: $language link $want matches ". join ' and ', @found);
                }
                if (@found == 0) {
                    $comic->keel_over("Comic::Out::HtmlLink: $language link refers to non-existent ${$references}{$ref}");
                }
            }
        }
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
