package Comics;

use strict;
use warnings;
use English '-no_match_vars';
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use Readonly;
use Carp;
use File::Slurper;
use File::Find;

use Comic;
use Comic::Settings;
use Comic::Out::Feed;
use Comic::Out::QrCode;


use version; our $VERSION = qv('0.0.3');

=for stopwords html Inkscape JSON merchantability perlartistic png submodules Wenner favicons cronjob RSS pngs notFor OutFile


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
    Comics::publish("/path/to/comics/svg/");

=head1 DESCRIPTION

This module simplifies working with individual Comics: finding input files,
having a main configuration, generating pngs and web pages.

=cut


# Default main configuration file.
Readonly my $MAIN_CONFIG_FILE => 'settings.json';


=head1 SUBROUTINES/METHODS

=head2 generate

Generate all files for all comics.

This is meant for to be a single method call to produce web pages from
comics, usable during development.

    perl -MComics -e 'Comics::generate("settings.json", "comics/");'

It will load the configuration from the given configuration file, collect the
comics in the passed directories, check them, export them as png, and generate
the web pages. It will not upload comics or post to social media.

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
    $comics->load_checks();

    my @files = $comics->collect_files(@dirs);
    foreach my $file (@files) {
        my $comic = Comic->new($file, $comics->{settings}->clone()->{settings});
        push @{$comics->{comics}}, $comic;
        $comic->check();
    }
    $comics->final_checks();

    my @outputters = $comics->{settings}->{Out} || ();
    foreach my $out (@outputters) {
        # ...
    }

    my $qr_code = Comic::Out::QrCode->new();
    $qr_code->generate(@{$comics->{comics}});

    $comics->generate_comic_pages();
    $comics->generate_feeds();

    $comics->generate_archive();
    $comics->generate_backlog();
    $comics->generate_sizemap();
    $comics->copy_static_web_files();

    return $comics;
}


=head2 publish

Publishes latest comic and any updates to previous comics.

This is meant as a single method to call to do everything needed to publish
a web comic, e.g. in a cronjob.

    perl -MComics -e 'Comics::publish("/home/robert/comics/bier/comics/web");'

It loads the configuration from the main configuration file, collects the
comics in the passed directories, checks them, exports them as png, generates
the web pages, uploads the comics, and posts the latest comic on social media.

Arguments:

=over 4

=item B<dir(s)> directories from which to collect comics.

=back

=cut

sub publish {
    my @dirs = @ARG;

    my $comics = generate(@dirs);
    $comics->upload();
    $comics->post_to_social_media();
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
            $self->{settings}->load_str(File::Slurper::read_text($file));
        }
    }

    return;
}


sub _exists {
    # uncoverable subroutine
    return -r shift;    # uncoverable statement
}


=head2 load_checks

Loads Check modules to check comics for certain problems.

=cut

sub load_checks() {
    my ($self) = @ARG;

    my $actual_settings = $self->{settings}->get();
    my $check_settings;
    if (exists $actual_settings->{$Comic::Settings::CHECKS}) {
        $check_settings = $actual_settings->{$Comic::Settings::CHECKS};
        if (ref $check_settings ne ref {}) {
            croak("'$Comic::Settings::CHECKS' must be a JSON object");
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


=head2 collect_files

Collects input comic files from given directories. Currently only C<.svg>
files are supported.

Arguments:

=over 4

=item B<files or directories> comic files to use or directories to search
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


=head2 generate_comic_pages

Generate a HTML page for each comic from a template.

The template file name must be given in the configuration for each language
like this:

    {
        "Html": {
            "Templates": {
                "English": "templates/comic-page.templ"
            },
            "OutDir": "generated/web/comics"
        }
    }

The HTML page will be the same name as the generated PNG, with a .html
extension, and it will be placed next to it.

=cut

sub generate_comic_pages {
    my ($self) = @ARG;

    foreach my $comic (@{$self->{comics}}) {
        $comic->export_png();
    }
    return Comic::export_all_html(%{$self->{settings}->{settings}->{'Templates'}});
}


=head2 generate_feeds

Generate RSS feeds for the web page.

All comics must have been loaded before calling this function.

=cut

sub generate_feeds {
    my ($self) = @ARG;

    # TODO test:
    #   does nothig if no Feed settings? warn? die?
    #   does nothing if no keys under Feeds
    #   fails noisily if no outdir given
    #   collects all Feed keys
    #   filters comics (by published when, published where)
    #   hookup in Comics.pm
    # do not test:
    #   no comics (template loop covers this)
    my $outdir = $self->{settings}->{settings}->{'Webdir'};
    my $settings = $self->{settings}->{settings}->{'Feeds'};
    if ($settings) {
        my $feed = Comics::Feed->new($outdir, $settings);
        $feed->generate(@{$self->{comics}});
    }
    return;
}


=head2 generate_archive

Generates a single HTML page per language with all published comics in
chronological order.

This function doesn't take arguments but uses these keys from the global
settings:

=over 4

=item B<Archive -E<gt> Templates> object of language to archive template file for
    that language. If a language doesn't have an archive template, it is
    silently skipped.

=item B<Archive_-E<gt> OutFile> reference to a hash of language to the archive
    page html file (including path). This allows for language-specific
    names, e.g., "generated/web/english/archive.html" for English and
    "generated/web/spanish/archivo.html" in Spanish.

=back

Makes these variables available during template processing:

=over 4

=item B<comics> array of published comics, sorted from oldest to latest.

=item B<modified> last modification date of the latest comic, to be used in
time stamps in e.g., HTML headers.

=item B<notFor> function that takes a comic and a language and returns
whether the given comic is for the given language. This is useful if you
want just one template for all languages.

=back

=cut

sub generate_archive {
    my ($self) = @ARG;

    my $archive_templates = $self->{settings}->{settings}->{'Archive'}->{'Templates'};
    my $archive_pages = $self->{settings}->{settings}->{'Archive'}->{'OutFile'};
    return _generate_archive($archive_templates, $archive_pages, @{$self->{comics}});
}


sub _generate_archive {
    my ($archive_templates, $archive_pages, @comics) = @ARG;

    foreach my $language (sort keys %{$archive_templates}) {
        my @published = sort Comic::from_oldest_to_latest grep {
            !$_->not_yet_published() && $_->_is_for($language)
        } @comics;
        next if (!@published);

        my %vars;
        $vars{'comics'} = \@published;
        $vars{'modified'} = $published[-1]->{modified};
        $vars{'notFor'} = \&Comic::not_for;

        my $templ_file = ${$archive_templates}{$language};
        my $output_file = ${$archive_pages}{$language};
        Comic::write_file($output_file, Comic::Out::Template::templatize('archive', $templ_file, $language, %vars));
    }

    return;
}


=head2 generate_backlog

Generate the HTML backlog page with unpublished comics and internal stats on all comics.

=cut

sub generate_backlog {
    my ($self) = @ARG;
    return;
}


=head2 generate_sizemap

Generate a map of comic sizes. This is meant for experimenting with
different image sizes.

=cut

sub generate_sizemap {
    my ($self) = @ARG;
    return;
}


=head2 copy_static_web_files

Copies static (i.e., not generated) parts of the web pages from a given
folder. This usually includes favicons, CSS styles, and imprint pages.

=cut

sub copy_static_web_files {
    my ($self) = @ARG;
    return;
}


=head2 upload

Upload generated web pages to a server.

=cut

sub upload {
    my ($self) = @ARG;
    return;
}


=head2 post_to_social_media

Post the latest comic to social media.

=cut

sub post_to_social_media {
    my ($self) = @ARG;
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
