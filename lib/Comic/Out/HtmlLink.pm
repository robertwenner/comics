package Comic::Out::HtmlLink;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Generator;
use base('Comic::Out::Generator');


=for stopwords Wenner merchantability perlartistic svg html metadata

=head1 NAME

Comic::Out::HtmlLink - Generates a reference ("see that other comic") from
comic metadata.

=head1 SYNOPSIS

    my $htmllink = Comic::Out::HtmlLink->new();
    $htmllink->generate_all(@comics);

=head1 DESCRIPTION

Generates links to other comics that can be used in HTML.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::HtmlLink.

The constructor takes no arguments.

Actual linking is triggered by comic meta data within a C<see> object. This
is language specific, so it needs a nested language object with a link text
as key and a svg file as value.

    "see":
        "English": {
            "First reopening": "comics/web/beergarden-reopened.svg"
        }

Link targets are given as svg source file names so that a referrer does not
depend on the actual title (and hence URL) of the linked comic.
Also, other forms of linking (e.g., to a page in a book) may not even have
meta data like an html output file, but all comics do have a title.

Links are per-language cause the link text varies by language.

=cut


sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    %{$self->{settings}} = ();
    return $self;
}


=head2 generate_all

Generates the references in all comics that want them.

Parameters:

=over 4

=item * B<@comics> All Comics to consider.

=back

Adds a new field to each Comic that wants to link somewhere:

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

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            if (!defined $comic->{meta_data}->{see} || !defined $comic->{meta_data}->{see}{$language}) {
                next;
            }

            my $references = $comic->{meta_data}->{see}{$language};
            foreach my $ref (keys %{$references}) {
                my $found = 0;
                foreach my $c (@comics) {
                    if ($c->{srcFile} eq ${$references}{$ref}) {
                        $comic->{'htmllink'}{$language}{$ref} = $c->{url}{$language};
                        $found = 1;
                    }
                }

                if (!$found) {
                    $comic->warning("$language link refers to non-existent ${$references}{$ref}");
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
