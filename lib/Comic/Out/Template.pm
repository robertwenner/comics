package Comic::Out::Template;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use File::Slurper;
use Template;
use Template::Plugin::JSON;

use version; our $VERSION = qv('0.0.3');


=for stopwords Wenner merchantability perlartistic templatize templating

=head1 NAME

Comic::Out::Template - wraps Perl's Template module, adding extra checks for
correct use.

=head1 SYNOPSIS

    Comic::Out::Template::templatize('...', 'my.templ', 'English', %vars);

=head1 DESCRIPTION

This module adds some checks around templating, in particular, it catches
any bad template markers.

=cut


=head1 SUBROUTINES/METHODS

=head2 templatize

Reads a template, processes it, and returns the output.

Parameters:

=over 4

=item * B<$description> For what a template is processed. This can be the
    input file name, or a descriptive text. Used in error messages.

=item * B<$template_file> Path and name of the template file.

=item * B<$language> For which language the template is used. This should be
    a language name starting with an upper case letter, e.g., "English".
    This function makes the language available during template processing as
    "Language" for the language as passed, and as "language" with a
    lowercase first letter. This can be used for including other templates
    based on the language.

=item * B<%vars> Any variables to be defined for use in the template.

=back

=cut

sub templatize {
    my ($description, $template_file, $language, %vars) = @ARG;

    # TODO: could cache templates, so that the same comic template does not
    # get reloaded for each comic
    my %options = (
        STRICT => 1,
        PRE_CHOMP => 0, # removes space in beginning of a directive
        POST_CHOMP => 2, # removes spaces after a directive
        # TRIM => 1,    # only used for BLOCKs
        VARIABLES => {
            'Language' => $language,
            'language' => lcfirst($language),
        },
        ENCODING => 'utf8',
    );
    my $t = Template->new(%options);
    # uncoverable branch true
    if (!$t) {
         croak('Cannot construct template: ' . Template->error());  # uncoverable statement
    }
    my $template = File::Slurper::read_text($template_file);

    my $output = '';
    $t->process(\$template, \%vars, \$output) ||
        croak "$template_file for $description: " . $t->error() . "\n";

    if ($output =~ m/\[%/mg || $output =~ m/%\]/mg) {
        croak "$template_file for $description: Unresolved template marker";
    }
    if ($output =~ m/ARRAY[(]0x[[:xdigit:]]+[)]/mg) {
        croak "$template_file for $description: ARRAY ref found:\n$output";
    }
    if ($output =~ m/HASH[(]0x[[:xdigit:]]+[)]/mg) {
        croak "$template_file for $description: HASH ref found:\n$output";
    }

    # Remove leading white space from lines. Template options don't work
    # cause they also remove newlines.
    $output =~ s/^ *//mg;
    return $output;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Perl Template module.


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
