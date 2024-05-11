package Comic::Modules;

use strict;
use warnings;
use utf8;

use English '-no_match_vars';
use Carp;
use File::Find;

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords Wenner merchantability perlartistic


=head1 NAME

Comic::Modules - Dynamically load Perl modules for use with Comic.


=head1 VERSION

This document refers to version 0.0.3.


=head1 SYNOPSIS

    use Comic::Modules;


=head1 DESCRIPTION

Dynamically load Perl modules so that different Comics can have different
checks and output generators.

This is an internal module and should not be used directly.

=cut


=head1 SUBROUTINES/METHODS

=head2 find_modules

Finds all modules that match a certain name.

Installed modules should be found automatically. In case of multiple modules
with the same name, the first one found will be used. Adjust C<@INC> to
configure in what locations to look in what order.

Parameters:

=over 4

=item * B<$match> find only modules where the name matches the given regular
    expression.

=item * B<$ignore> what to ignore (e.g., base class name).

=back

=cut

sub find_modules {
    my ($match, $ignore) = @ARG;

    # Collect modules in a hash; modules may be installed or may (also)
    # exist in a user-defined location (e.g, during development). We only
    # need the name once and leave it to the users to configure @INC
    # according to their priorities.
    my %found;

    find({
        wanted => sub {
            my $name = $File::Find::name;
            if ($name =~ $match) {
                $name = $1;
                if ($name ne $ignore) {
                    # Exclude this abstract base class.
                    $found{$name}++;
                }
            }
        },
        no_chdir => 1,
        follow => 1,
        follow_skip => 2,
    }, @INC);

    return keys %found;
}


=head2 load_module

Loads a Perl module dynamically.

Parameters:

=over 4

=item * B<$name> name of the module to load, this can either be a module name as
    in C<use> (for example C<Comic::Check::SomeCheck>) or a path / file name
    of the module (e.g., C<Comic/Check/SomeCheck.pm>). The module must be in
    a path in C<@INC>.

=item * B<$arguments> reference to an array or hash of the arguments to pass
    to the new module's constructor.

=back

Returns an instance of the newly loaded module, or C<undef> if the setting was not
loadable as a module and didn't look like one.

=cut

sub load_module {
    my ($name, $args) = @ARG;

    my $filename = module_path($name);
    eval {
        require $filename;
        $filename->import();
        1;  # indicate success, or we may end up with an empty eval error
    }
    or do {
        # If the setting does not look like a module (i.e., doesn't end in .pm and
        # doesn't have the :: that separate package names, assume it's a setting.
        if ($name=~ m{[.]pm$}x || $name =~ m{::}x) {
            croak("Error loading $name ($filename): $EVAL_ERROR");
        }
        return;
    };

    my @args;
    if (ref $args eq ref {}) {
        @args = %{$args};
    }
    elsif (ref $args eq ref []) {
        @args = @{$args};
    }
    elsif (ref $args eq ref $name) {
        push @args, $args;
    }
    else {
        croak('Cannot handle ' . (ref $args) . " for $name arguments");
    }

    my $classname = module_name($filename);
    my $instance = $classname->new(@args);
    return $instance;
}


=head2 module_name

Converts a path to a module to its name as it would be used in a C<use> or
C<require>.

Parameters:

=over 4

=item * B<$name> path / file name of the module, e.g., C<Comic/Check/Check.pm>.

=back

=cut

sub module_name {
    my ($name) = @ARG;

    $name =~ s/[.]pm$//;
    $name =~ s{/}{::}g;

    return $name;
}


=head2 module_path

Converts a Perl module name as used in a C<use> or C<require> to a relative path.

Parameters:

=over 4

=item * B<$name> Module name, e.g., C<Comic::Check::Check>.

=back

=cut

sub module_path {
    my ($name) = @ARG;

    $name =~ s{::}{/}g;
    $name = "$name.pm" unless $name =~ m/[.]pm$/;

    return $name;
}


1;


=head1 DIAGNOSTICS

None.


=head1 DEPENDENCIES

None.


=head1 CONFIGURATION AND ENVIRONMENT

Uses Perl's module finding mechanism (e.g., C<@INC>).


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
