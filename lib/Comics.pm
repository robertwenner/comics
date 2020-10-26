package Comics;

use strict;
use warnings;
use English '-no_match_vars';
use Readonly;
use Carp;
use File::Slurp;

use Comic;
use Comic::Settings;


use version; our $VERSION = qv('0.0.3');

=for stopwords Inkscape JSON merchantability perlartistic png submodules Wenner


=head1 NAME

Comics - Exports comics in multiple languages from Inkscape files to png and
generates web pages for these.


=head1 SYNOPSIS

    use Comics;

    # Detailled:
    my $comics = Comics->new();
    $comics->load_settings("my-settings.json");
    $comics->load_comics("comics/");
    $comics->export_all();

    # Lazy cronjob:
    Comic::publish();

=head1 DESCRIPTION

This module simplifies working with individual Comics: finding input files,
having a main configuration, exporting, and generating the web pages.

=cut


# Default main configuration file.
Readonly my $MAIN_CONFIG_FILE => 'comic-perl-config.json';


=head1 SUBROUTINES/METHODS

=head2 publish

Publishes all comics.

This is meant for non-programmers that just want to call a single method to
do everything needed to publish a web comic.

It will load the configuration from the main configuration file, collect the
comics in the passed directories, check them, export them as png, generate
the web pages, and post the latest comic on social media.

Arguments:

=over 4

=item B<dir(s)> directories from which to collect comics.

=back

=cut

sub publish {
#    my @dirs = @ARG;
#
#    my $comics = Comics->new();
#    $comics->load_settings($MAIN_CONFIG_FILE);
#    $comics->load_checks();
#    my @files = $comics.collect_files();
#    foreach my $file (@files) {
#        my $comic = Comic->new($file, $comics->{settings}->clone());
#        $comic->check();
#        $comic->export_png();
#        push @{$self->{comics}}, $comic;
#    }
#    $comics.final_checks();
#    $comics.generate_comic_pages();
#    $comics.generate_rss_feeds();
#    $comics.generate_archive();
#    $comics.generate_backlog();
#    $comics.generate_sizemap();
#    $comics.copy_static_web_files();
#    $comics.post_to_social_media();
    return;
}


=head2 new

Creates a new Comics collection.

=cut

sub new {
    my ($class) = @ARG;
    my $self = bless{}, $class;
    $self->{settings} = Comic::Settings->new();
    $self->{checks} = [];
    $self->{comics} = [];
    return $self;
}


=head2 load_settings

Loads settings for Comics from the given configuration files.

Arguments:

=over 4

=item B<file(s)> configuration files.

=back

=cut

sub load_settings {
    my ($self, @files) = @ARG;

    foreach my $file (@files) {
        if (_exists($file)) {
            $self->{settings}->load_str(File::Slurp::slurp($file));
        }
    }

    return;
}


sub _exists {
    # uncoverable subroutine
    return -r shift;
}


=head2 load_checks

Loads Check modules to check comics for certain problems.

=cut

sub load_checks() {
    my ($self) = @ARG;

    my $actual_settings = $self->{settings}->get();
    my $check_settings;
    if (exists $actual_settings->{'Check'}) {
        $check_settings = $actual_settings->{'Check'};
        if (ref $check_settings ne ref {}) {
            croak('"Check" must be a JSON object');
        }
    }
    else {
        $check_settings = { map { $_ => [] } Comic::Check::Check::find_all() };
    }

    foreach my $name (keys %{$check_settings}) {
        Comic::Check::Check::load_check($self->{checks}, $name, ${$check_settings}{$name} || []);
    }
    return;
}


=head2 final_checks

Runs the final checks method for all loaded Checks, giving them a chance to
do their checks after having seen all Comics.

=cut

sub final_checks {
    my ($self) = @ARG;

    my %called;
    foreach my $check (@{$self->{checks}}) {
        $check->final_check() unless ($called{$check});
        $called{$check} = 1;
    }

    foreach my $comic (@{$self->{comics}}) {
        foreach my $check (@{$comic->{checks}}) {
            $check->final_check() unless ($called{$check});
            $called{$check} = 1;
        }
    }

    return;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Comic module and its submodules.


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

JSON configuration files.

Inkscape must be installed and on the C<$PATH>.


=head1 INCOMPATIBILITIES

None known.


=head1 BUGS AND LIMITATIONS

Only tested on Linux.


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
