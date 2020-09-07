package Comic::Check::Title;

use strict;
use warnings;
use English '-no_match_vars';
use String::Util 'trim';

use version; our $VERSION = qv('0.0.3');


=head1 NAME

Comic::Check::Title - Checks a comic's title to prevent duplicate titles.

=head1 SYNOPSIS

    my $check = Comic::Check::Title->new();
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }

=head1 DESCRIPTION

Duplicate titles make it impossible to uniquely refer to a particular comic
and could lead to file name clashes when the title is used for the output
image and HTML page file names.

Comic::Check::Title keeps track of the titles it has seen, so you need to
use the same instance for checking all your comics.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Title.

=cut


sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    $self->{titles} = ();
    return $self;
}


=head2 check

Checks the given Comic's title.

Parameters:

=over 4

=item * Comic to check. Will check the title for all languages the comic has.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    foreach my $language ($comic->_languages()) {
        my $title = $comic->{meta_data}->{title}->{$language};
        my $key = trim(lc "$language\n$title");
        $key =~ s/\s+/ /g;
        if (defined $self->{titles}{$key}) {
            if ($self->{titles}{$key} ne $comic->{srcFile}) {
                $comic->_warn("Duplicated $language title '$title' in $self->{titles}{$key}");
            }
        }
        $self->{titles}{$key} = $comic->{srcFile};
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
