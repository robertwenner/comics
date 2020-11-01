package Comic::Check::DuplicatedTexts;

use strict;
use warnings;
use English '-no_match_vars';
use String::Util 'trim';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=head1 NAME

Comic::Check::DuplicatedTexts - Checks a comic's transcript for duplicated texts.

=head1 SYNOPSIS

    my $check = Comic::Check::DuplicatedTexts->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }

=head1 DESCRIPTION

Comic::Check::DuplicatedTexts doesn't keeps track of comics. It's safe to be shared
but doesn't need to be shared.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::DuplicatedTexts.

=cut


sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 check

Checks that the given Comic has no duplicated texts, which could be copy
& paste errors and texts forgotten to translate.

Before comparing, texts are normalized: line breaks are replaced by spaces,
multiple spaces are reduced to one. However, checks are case-sensitive, so
that you can still use "Pale Ale" in German and "pale ale" in English.

If a comic defines a meta variable C<allow-duplicated>, these texts are not
flagged as duplicated. This also works for multi-line texts; just use a
regular space instead of a line break when configuring this.

For example:

    {
        "allow-duplicated": [
            "Pils", "multi line text"
        ]
    }


Any text that looks like a speaker introduction (i.e., ends in a colon) is
allowed do be duplicated as well, so that characters can have the same names
in different languages without having to define an C<allow-duplicated>
exception each time.

We should probably only check this for texts from the meta layer, but this
Check is layer-agnostic (i.e., too dumb for this).

Parameters:

=over 4

=item * Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    my $allow_duplicated = $comic->{meta_data}->{'allow-duplicated'} || [];
    my %allow_duplicated = map { _normalize_text($_) => 1 } @{$allow_duplicated};

    my %seen;
    foreach my $language ($comic->languages()) {
        foreach my $text ($comic->texts_in_layer($language)) {
            $text = _normalize_text($text);
            next if (defined $allow_duplicated{$text});
            next if ($text =~ m/:$/);
            if (defined $seen{$text}) {
                $comic->_croak("duplicated text '$text' in $seen{$text} and $language");
            }
            $seen{$text} = $language;
        }
    }
    return;
}


sub _normalize_text {
    # Normalize texts for easier comparison. Change all spaces to a single
    # space. That way we catch differences in white space, which is probably
    # a bad attempt at duplicating texts, or even sloppy typing that has
    # only been edited in one language. This also catches multi-line texts,
    # where the whole multi line text can be added as a single element in
    # allow-duplicated.
    # Does not mess with case cause that shouln't be duplicated. For example,
    # a character may say "pale ale" in English and "Pale Ale" in German.
    my ($text) = @_;
    $text = trim($text);
    $text =~ s/\s+/ /mg;
    return $text;
}


=for stopwords html Wenner merchantability perlartistic


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

Copyright (c) 2015 - 2020, Robert Wenner C<< <rwenner@cpan.org> >>.
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
