package Comic::Social::Social;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords Wenner merchantability perlartistic


=head1 NAME

Comic::Social::Social - base class for modules posting to social media.


=head1 SYNOPSIS

This class cannot be used directly.


=head1 DESCRIPTION

Use classes derived from this class.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Social::Social.

=cut

sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    return $self;
}


=head2 post

Posts the given Comic to the social network using the configured settings.

Parameters:

=over 4

=item * B<$comic> Comic to post.

=back

Returns any messages from posting, separated by newlines.

=cut

sub post {
    # uncoverable subroutine
    croak('Comic::Social::Social::post should have been overridden'); # uncoverable statement
}


=head2 collect_hashtags

Collects the given Comic's hashtags in the given language.

Parameters:

=over 4

=item * B<$comic> Comic from which to collect hashtags.

=item * B<$language> For which language to collect hashtags.

=item * B<$metatags> Names in the Comic's metadata from which to collect
    hashtags. Only specify social network specific names. Do not include
    C<hashtags>, as this is picked first automatically.

=back

Returns all hashtags found in order, starting with the ones from
C<hashtags>.

=cut

sub collect_hashtags {
    my ($comic, $language, @metatags) = @ARG;

    my @hashtags;
    foreach my $loc ('hashtags', @metatags) {
        my $hashtags = $comic->{meta_data}->{$loc}->{$language};
        if ($hashtags) {
            push @hashtags, @{$hashtags};
        }
    }
    return @hashtags;
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

Copyright (c) 2015 - 2022, Robert Wenner C<< <rwenner@cpan.org> >>.
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
