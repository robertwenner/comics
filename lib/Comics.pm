package Comics;

use strict;
use warnings;
use autodie;

use English '-no_match_vars';
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use Readonly;
use Carp;
use File::Slurper;
use File::Find;

use Comic;
use Comic::Settings;
use Comic::Check::Check;
use Comic::Out::Generator;
use Comic::Upload::Uploader;
use Comic::Social::Social;


use version; our $VERSION = qv('0.0.3');

=for stopwords html Inkscape JSON merchantability perlartistic png submodules Wenner cron cronjob pngs uploader uploaders


=head1 NAME

Comics - Exports comics in multiple languages from Inkscape files to png and
generates web pages for these.

=head1 SYNOPSIS

    use Comics;

    # Detailled:
    my $comics = Comics->new();
    $comics->load_settings("my-settings.json");
    $comics->collect_files("/path/to/comics/svg/");
    $comics->load_checks();
    $comics->run_all_checks();
    $comics->load_generators();
    $comics->generate_all();
    if ($want_to_upload) {
        $comics->load_uploaders();
        $comics->upload_all_comics();
        if ($wants_to_post_todays_comic_to_social_media) {
            $comics->load_social_media_posters();
            $comics->post_todays_comic_to_social_media();
        }
    }

    # Simple command to check comics and generate output:
    Comics::generate("config.json", "comics/");

    # Simple command to sync local comics to a web server:
    Comics::upload("config.json", "comics/");

    # Cronjob to publish comics:
    Comics::post_todays_comic("/path/to/config.json", "/path/to/comics/svg/");

=head1 DESCRIPTION

This module simplifies working with individual Comics: finding input files,
having a main configuration, generating pngs and web pages.

=cut


=head1 SUBROUTINES/METHODS

=head2 generate

Generate all files for all comics.

This is meant for to be a single method call to produce web pages from
comics during development, e.g., to quickly run the checks on a comic in
progress and see its web page.

    perl -MComics -e 'Comics::generate("settings.json", "comics/");'

It will load the configuration from the given configuration file, collect
the comics in the passed directories, run all configured checks on them, and
run all configured output generators on them.

Arguments:

=over 4

=item * B<$config> configuration file to use.

=item * B<@dir(s)> directories from which to collect comics.

=back

=cut

sub generate {
    my ($config, @dirs) = @ARG;

    my $comics = Comics->new();
    $comics->load_settings($config);

    my @files = $comics->collect_files(@dirs);
    unless (@files) {
        croak('No comics found; looked in ' . join ', ', @dirs);
    }

    foreach my $file (@files) {
        my $comic = Comic->new($comics->{settings}->clone()->{settings});
        $comic->load($file);
        push @{$comics->{comics}}, $comic;
    }

    $comics->load_checks();
    $comics->run_all_checks();

    $comics->load_generators();
    $comics->generate_all();

    return $comics;
}


=head2 upload

Uploads all comics.

This is meant as a single method to sync the local comics with a web server.

It calls the C<generate> function, then runs the configured uploaders.

Arguments:

=over 4

=item * B<$config> path to the configuration file.

=item * B<@dirs> directories from which to collect comics.

=back

=cut

sub upload {
    my ($config, @dirs) = @ARG;

    my $comics = generate($config, @dirs);
    $comics->load_uploaders();
    unless (@{$comics->{uploaders}}) {
        croak('No uploaders configured');
    }
    $comics->upload_all_comics();

    return $comics;
}


=head2 post_todays_comic

Generates all comics, uploads them, and posts today's comic(s) to social
media.

This is meant as a single method to call to do everything needed to publish
a new comic and post it to social media, e.g. in a cronjob.

    perl -MComics -e 'Comics::publish("/home/robert/comics/bier/config.json", "/home/robert/comics/bier/comics/web");'

This function will print any output from the social media posting plugins to
standard out. The cron daemon should pick that up and email it to the owner.

This module does not know whether a comic was already posted. As a simple
check, it won't post if the comic was not released today.

Arguments:

=over 4

=item * B<$config> path to the configuration file.

=item * B<@dirs> directories from which to collect comics.

=back

=cut

sub post_todays_comic {
    my ($config, @dirs) = @ARG;

    my $comics = upload($config, @dirs);
    $comics->load_social_media_posters();
    unless (@{$comics->{social_media_posters}}) {
        croak('No social media posters configured');
    }

    my @output = $comics->post_todays_comic_to_social_media();
    foreach my $line (@output) {
        # It's probably safe to print to stdout...
        ## no critic(InputOutput::RequireCheckedSyscalls)
        print "$line\n";
        ## use critic
    }

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
    $self->{generators} = [];
    $self->{uploaders} = [];
    $self->{social_media_posters} = [];
    $self->{comics} = [];
    return $self;
}


=head2 load_settings

Loads settings for Comics from the given configuration file(s).

Arguments:

=over 4

=item * B<@file(s)> configuration files.

=back

=cut

sub load_settings {
    my ($self, @files) = @ARG;

    foreach my $file (@files) {
        if (_is_directory($file)) {
            croak("Cannot read directory $file");
        }
        if (!_exists($file)) {
            croak("$file not found");
        }
        $self->{settings}->load_str(File::Slurper::read_text($file));
    }

    return;
}


sub _exists {
    # uncoverable subroutine
    return -r shift;    # uncoverable statement
}


=head2 load_checks

Loads the Checks modules defined in this Comics' configuration.

=cut

sub load_checks {
    my ($self) = @ARG;

    push @{$self->{checks}}, $self->_load_modules($Comic::Settings::CHECKS, \&Comic::Check::Check::find_all);
    return;
}


=head2 load_generators

Loads all output generating modules configured in the current configuration.

=cut

sub load_generators {
    my ($self) = @ARG;

    push @{$self->{generators}}, $self->_load_modules($Comic::Settings::GENERATORS, sub { return () }, 'No output generators configured');
    return;
}


=head2 load_uploaders

Loads all configured uploader modules.

=cut

sub load_uploaders {
    my ($self) = @ARG;

    push @{$self->{uploaders}}, $self->_load_modules($Comic::Settings::UPLOADERS, sub { return () });
    return;
}


=head2 load_social_media_posters

Loads all social media posting modules.

=cut

sub load_social_media_posters {
    my ($self) = @ARG;

    push @{$self->{social_media_posters}}, $self->_load_modules($Comic::Settings::SOCIAL_MEDIA_POSTERS, sub { return () });
    return;
}


sub _load_modules {
    my ($self, $type, $get_default_modules, $error_if_no_modules) = @ARG;

    my $actual_settings = $self->{settings}->get();
    my $wants_to_load;
    if (exists $actual_settings->{$type}) {
        $wants_to_load = $actual_settings->{$type};
        if (ref $wants_to_load ne ref {}) {
            croak("'$type' must be a JSON object");
        }
    }
    else {
        $wants_to_load = { map { $_ => [] } &{$get_default_modules} };
    }

    my @loaded;
    foreach my $name (keys %{$wants_to_load}) {
        my $module_args = ${$wants_to_load}{$name} || [];
        push @loaded, Comic::Modules::load_module($name, $module_args);
    }

    if (!@loaded && $error_if_no_modules) {
        # No modules configured or found by default, but needs some --- bail out.
        croak($error_if_no_modules);
    }

    return @loaded;
}


=head2 collect_files

Collects input comic files from given directories. Currently only C<.svg>
files are supported.

Arguments:

=over 4

=item * B<files or directories> comic files to use or directories to search
    for comics. If you give file names, these files will be collected
    regardless of their extension, where any directories will only be
    scanned for supported files.

    Pass a relative path for directories if you usually use relative paths,
    e.g., in the C<see> comic meta data to refer to another comic. Later
    code checking paths may or ay not be aware of the current directory and
    hence not find referenced files.

=back

=cut

sub collect_files {
    my ($self, @files_or_dirs) = @ARG;

    my @collection;
    foreach my $fod (@files_or_dirs) {
        if (_is_directory($fod)) {
            File::Find::find(
                sub {
                    my $name = $File::Find::name;
                    push @collection, $name if ($name =~ m/\.svg$/);
                },
                $fod);
        }
        else {
            push @collection, $fod;
        }
    }
    return @collection;
}


sub _is_directory {
    # uncoverable subroutine
    return -d shift;    # uncoverable statement
}


=head2 run_all_checks

Runs all configured checks for all loaded Comics.

=cut

sub run_all_checks {
    my ($self) = @ARG;

    foreach my $comic (@{$self->{comics}}) {
        foreach my $check (@{$self->{checks}}) {
            $check->check($comic);
        }
    }

    return;
}


=head2 run_final_checks

Runs the final checks method for all loaded Checks, giving them a chance to
do their checks after having seen all Comics.

=cut

sub run_final_checks {
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


=head2 generate_all

Run all configured generators on all loaded comics.

=cut

sub generate_all {
    my ($self) = @ARG;

    foreach my $gen (@{$self->{generators}}) {
        foreach my $comic (@{$self->{comics}}) {
            $gen->generate($comic);
        }
    }

    # Run all per-comic generators before working on generators for all
    # comics, so that the later can access data generated by the former ones
    # (e.g., comic URLs in the archive page).
    foreach my $gen (@{$self->{generators}}) {
        $gen->generate_all(@{$self->{comics}});
    }

    return;
}


=head2 upload_all_comics

Run all the configured uploaders to upload generated content somewhere.

=cut

sub upload_all_comics {
    my ($self) = @ARG;

    foreach my $uploader (@{$self->{uploaders}}) {
        $uploader->upload();
    }

    return;
}


=head2 post_todays_comic_to_social_media

Run all configured social media posting plugins to post today's comic to
social media.

Will not post a comic if it isn't published today, to avoid not having a
comic and then blasting out the posts for previous week's comic.

Returns log information (usually the URLs posted to and such) if successful,
or an error message if no current comic was found.

=cut

sub post_todays_comic_to_social_media {
    my ($self) = @ARG;

    return ("Not posting: no comics\n") unless (@{$self->{comics}});

    my @comics = _todays_comics(@{$self->{comics}});
    if (!@comics) {
        return ("Not posting cause latest published comic is not from today\n");
    }

    my @posted;
    foreach my $comic (@comics) {
        push @posted, $self->post_to_social_media($comic);
    }

    return @posted;
}


sub _todays_comics {
    my @comics = @ARG;

    my @published = reverse sort Comic::from_oldest_to_latest grep {
        !$_->not_yet_published()
    } @comics;
    my @todays;
    foreach my $comic (@published) {
        # Sorted by date, so it's safe to exit the loop at the first comic
        # that's not up to date. This still allows to post multiple comics
        # with the same date, which can happen when comics for a day cannot
        # be translated and there are separate ones per language.
        last unless ($comic->is_published_today());
        push @todays, $comic;
    }
    return @todays;
}


=head2 post_to_social_media

Posts the given Comic to all configured social media.

Arguments:

=over 4

=item * B<$comic> the comic to post

=back

Returns an array of any messages from posting.

=cut

sub post_to_social_media {
    my ($self, $comic) = @ARG;

    my @posted;
    foreach my $poster (@{$self->{social_media_posters}}) {
        push @posted, $poster->post($comic);
    }

    return @posted;
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

Copyright (c) 2020 - 2021, Robert Wenner C<< <rwenner@cpan.org> >>.
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
