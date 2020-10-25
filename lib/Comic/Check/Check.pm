package Comic::Check::Check;

use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use File::Find;

use version; our $VERSION = qv('0.0.3');


=head1 NAME

Comic::Check::Check  - base class for all comic checks.

=head1 SYNOPSIS

Should not be used directly.

=head1 DESCRIPTION

All Comic::Checks should derive from this class.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check::Check.

=cut


sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    @{$self->{comics}} = ();
    return $self;
}


=head2 notify

Notifies this Check of the given comic. This does not mean to check the
given comic, but keep it in mind for checks that compare comics to
previously seen ones.

The base class implementation just remembers the passed comic in its
C<comics> array. Derived classes can access that comic array in e.g.,
C<final_check>.

Parameters:

=over 4

=item * Comic to remember.

=back

=cut

sub notify {
    my ($self, $comic) = @ARG;

    push @{$self->{comics}}, $comic;
    return;
}


=head2 check

Checks the given Comic.

The base class implementation croaks. Derived classes need to implement this
method and do whatever per-comic checks they need to do.

Parameters:

=over 4

=item B<comic> Comic to check.

=back

=cut

sub check {
    # uncoverable subroutine
    croak('Comic::Check::Check should have been overridden');
}


=head2 final_check

Checks all previously collected comics after all comics have been checked.

The base class implementation does nothing. Derived classes can override this
method to do checks once all comics have been seen, e.g., to check that a
series name is not unique (may be a typo).

=cut

sub final_check {
    # uncoverable subroutine
    # Ignore.
}


=head2 load_check

Loads a check dynamically.

Parameters:

=over 4

=item B<checks> reference to an array to put an instance of the loaded Check
    into.

=item B<name> name of the check to load, this can either be a module name as
    in C<use> (for example C<Comic::Check::SomeCheck>) or a path / file name
    of the module (e.g., C<Comic/Check/SomeCheck.pm>). The module must be in
    a path in C<@INC>.

=item B<arguments> reference to an array or hash of the arguments to pass to
    the new Check's constructor.

=back

=cut

sub load_check {
    my ($checks, $name, $args) = @ARG;

    my $filename = module_path($name);
    eval {
        require $filename;
        $filename->import();
        1;  # indicate success, or we may end up with an empty eval error
    }
    or croak("Error using check $filename: $EVAL_ERROR");

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

    my $module = module_name($filename);
    my $check = $module->new(@args);
    push @{$checks}, $check;

    return;
}


=head2 module_name

Converts a path to a module to its name as it would be used in a C<use> or
C<require>.

Parameters:

=over 4

=item B<name> path / file name of the module, e.g., C<Comic/Check/Check.pm>.

=back

=cut

sub module_name {
    my ($name) = @ARG;

    $name =~ s/\.pm$//;
    $name =~ s{/}{::}g;

    return $name;
}


=head2 module_path

Converts a Perl module name as used in a C<use> or C<require> to a relative path.

Parameters:

=over 4

=item B<name> Module name, e.g., C<Comic::Check::Check>.

=back

=cut

sub module_path {
    my ($name) = @ARG;

    $name =~ s{::}{/}g;
    $name = "$name.pm" unless $name =~ m/\.pm$/;

    return $name;
}


=head2 find_all

Finds all Check modules available. This is used to enable all modules.
Installed modules should be found automatically. In case of multiple modules
by the same name, adjust C<@INC> to configure what actually gets used.

=cut

sub find_all {
    # Collect check modules in a hash; modules may be installed, and also
    # exist in a user-defined location (e.g, during development). We only
    # need the name once and leave it to the users to configure @INC
    # according to their priorities.
    my %checks;

    find({
        wanted => sub {
            my $name = $File::Find::name;
            if ($name =~ m{/(Comic/Check/[^.]+\.pm)$}) {
                $name = $1;
                if ($name ne 'Comic/Check/Check.pm') {
                    # Exclude this abstract base class.
                    $checks{$name}++;
                }
            }
        },
        follow => 1,
        follow_skip => 2,
    }, @INC);

    return keys %checks;
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

Copyright (c) 2020, Robert Wenner C<< <rwenner@cpan.org> >>.
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
