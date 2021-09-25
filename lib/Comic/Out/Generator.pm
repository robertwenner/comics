package Comic::Out::Generator;

use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use Comic::Modules;

use version; our $VERSION = qv('0.0.3');


=for stopwords html Wenner merchantability perlartistic png html


=head1 NAME

Comic::Out::Generator - base class for all Comic modules that produce output.

=head1 SYNOPSIS

Should not be used directly.

=head1 DESCRIPTION

All Comic::Out modules should derive from this class.

Generators are configured in the configuration file. They are called in the
order they are defined in.

A generator can use one or both methods of generating output:

=over 4

=item * for each comic (in the C<generate> method), like generating a PNG
image or HTML page for the comic

=item * for all comics together (C<generate_all> method), like an overview
page

=back

Generators may ignore either of these methods; the default implementation
does nothing. (Of course, if you don't override at least one of these
methods, your generator does not generate anything.)

When a comic is processed, first all configured Generators are asked to
generate per-comic output (C<generate> method). When that is done, all
Generators are asked to generate output for all comics (C<generate_all>
method). That way the C<generate_all> method can access comic data generated
by previous generators, for example, an overview page can use the URL that a
per-comic html page generator created and stored in each Comic.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Generator.

=cut


sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    return $self;
}


=head2 generate

Generate whatever output this Generator wants to generate for a given Comic.
This is called once for each comic to generate e.g., the comic's image or web page.

Parameters:

=over 4

=item * B<$comic> Comic to generate output for.

=back

=cut

sub generate {
    # Ignore.
    return;
}


=head2 generate_all

Generate output for all Comics.

This is called once with all comics to generate output that is not specific
for one comic, like an overview page.

Parameters:

=over 4

=item * B<@comics> Comics to generate output for.

=back

=cut

sub generate_all {
    # Ignore.
    return;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

Comic::Module.


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

Copyright (c) 2021, Robert Wenner C<< <rwenner@cpan.org> >>.
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
