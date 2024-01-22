package Comic::Check::Actors;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8


=head1 NAME

Comic::Check::Actors - Checks the actors in a comic for consistency between
languages.


=head1 SYNOPSIS

    my $check = Comic::Check::Actors->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }


=head1 DESCRIPTION

Comic::Check::Actors doesn't keeps track of comics. It's safe to be shared
but doesn't need to be shared.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Actors.

=cut


sub new {
    my ($class) = @ARG;
    my $self = $class->SUPER::new();
    return $self;
}


=head2 check

Checks that the given Comic's actors don't have empty names and that each
language has the same number of actors.

Actors meta data is expected to be an array at C<who> -E<gt> C<$language>.
For example:

    {
        "who": {
            "english": ["Paul", "Max", "speaking beer barrel"],
            "deutsch": ["Paul", "Max", "sprechendes Bierfaß"],
            "español": ["Paulo", "Max", "el barril que habla"]
        }
    }


Parameters:

=over 4

=item * B<$comic> Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    my $count_mismatch = 0;
    LANG: foreach my $language ($comic->languages()) {
        if (!defined($comic->{meta_data}->{who})) {
            $self->warning($comic, "No $language actors metadata at all");
            next LANG;
        }
        foreach my $l ($comic->languages()) {
            next if ($language eq $l);
            my $one = $comic->{meta_data}->{who}->{$l};
            my $two = $comic->{meta_data}->{who}->{$language};
            if ($one && $two && scalar @{$one} ne scalar @{$two} && !$count_mismatch) {
                $self->warning($comic, "Different number of actors in $language and $l");
                $count_mismatch = 1;
            }
        }
        foreach my $who (@{$comic->{meta_data}->{who}{$language}}) {
            $self->warning($comic, "Empty actor name in $language") if ($who =~ m{^\s*$});
        }
    }
    return;
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
