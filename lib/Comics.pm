package Comics;

use strict;
use warnings;
use utf8;
use autodie;

use Readonly;
use English '-no_match_vars';
use open ':std', ':encoding(UTF-8)'; # to handle e.g., umlauts correctly
use Carp;
use DateTime;
use File::Slurper;
use File::Find;
use File::Util;
use File::Basename;
use File::Path;
use JSON;

use Comic;
use Comic::Settings;
use Comic::Check::Check;
use Comic::Out::Generator;
use Comic::Upload::Uploader;
use Comic::Social::Social;


use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords html Inkscape JSON merchantability perlartistic submodules Wenner cron cronjob uploader uploaders


=head1 NAME

Comics - Exports comics in multiple languages from Inkscape files and generates
additional files like web pages.


=head1 SYNOPSIS

    use Comics;

    # Detailed:
    my $comics = Comics->new();
    $comics->load_settings('/path/to/config.json');
    check_settings(%{$comics->{settings}});

    $comics->load_checks();
    my @files = Comics::collect_files('/path/to/comics/dir');
    foreach my $file (@files) {
        my $comic = Comic->new($comics->{settings}->clone(), $comics->{checks});
        $comic->load($file);
        push @{$comics->{comics}}, $comic;
    }

    $comics->load_generators();

    $comics->run_all_checks();
    foreach my $comic (@{$comics->{comics}}) {
        foreach my $warning(@{$comic->{warnings}}) {
            print "$comic->{srcFile}: $warning\n";
        }
    }

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
    Comics::upload("/path/to/config.json");


    # Simple command (e.g., for a cronjob) to publish the latest comic,
    # including generating everything, uploading, and posting to social media:
    Comics::publish_comic('/path/to/config.json', '/path/to/comics/svg/');


=head1 DESCRIPTION

This module simplifies working with individual Comics: finding input files,
having a main configuration, generating C<pngs> and web pages.

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
    check_settings(%{$comics->{settings}});

    my @files = collect_files(@dirs);
    unless (@files) {
        croak('No comics found; looked in ' . join ', ', @dirs);
    }

    # load_settings above loaded the config file(s), so it knows here which
    # check modules it should eventually load with which parameters, but it
    # hasn't even tried loading them yet. Now load the actual check modules
    # and pass them to each Comic so that the Comic can copy and adjust them
    # based on its metadata.
    $comics->load_checks();

    foreach my $file (@files) {
        my $comic = Comic->new($comics->{settings}->clone(), $comics->{checks});
        $comic->load($file);
        push @{$comics->{comics}}, $comic;
    }

    # Must load the generators before running checks cause we ask the generators
    # if they're up to date to decide whether to run checks.
    $comics->load_generators();

    $comics->run_all_checks();
    foreach my $comic (@{$comics->{comics}}) {
        _print_warnings($comic);
    }

    $comics->generate_all();

    return $comics;
}


sub _print_warnings {
    my ($comic) = @ARG;

    my $count = scalar @{$comic->{warnings}};
    if ($count > 0) {
        _print_all($comic->{srcFile}, @{$comic->{warnings}});
        my $problems = 'problem';
        $problems .= 's' if ($count > 1);
        my $summary = "$count $problems in $comic->{srcFile}";
        if ($comic->not_yet_published()) {
            croak($summary);
        }
        else {
            # If this Comic is already published, treat any warning as an error,
            # and keel over. The intention is that most warnings should be addressed
            # (or the Check that causes them should be disabled), and it's okay only
            # for comics in progress to have pending warnings.
            _print_all($summary);
        }
    }

    return;
}


=head2 upload

Uploads all comics.

This is meant as a single method to sync the local comics with a web server.

Comic web pages need to be generated before calling this function.

Arguments:

=over 4

=item * B<$config> path to the configuration file.

=back

=cut

sub upload {
    my ($config) = @ARG;

    my $comics = Comics->new();
    $comics->load_settings($config);
    check_settings(%{$comics->{settings}});

    $comics->load_uploaders();
    unless (@{$comics->{uploaders}}) {
        croak('No uploaders configured');
    }
    _print_all($comics->upload_all_comics());

    return $comics;
}


=head2 publish_comic

Generates all comics, uploads them, and posts today's comic(s) to social
media.

This is meant as a single method to call to do everything needed to publish
a new comic and post it to social media, e.g. in a cronjob.

    perl -MComics -e 'Comics::publish("config.json", "comics/");'

This function will print any output from the social media posting plugins to
standard out. The cron daemon should pick that up and email it to the cron
job's owner.

This module does not know whether a comic was already posted. As a simple
check, it won't post if the comic was not released today.

Arguments:

=over 4

=item * B<$config> path to the configuration file.

=item * B<@dirs> directories from which to collect comics.

=back

=cut

sub publish_comic {
    my ($config, @dirs) = @ARG;

    my $comics = generate($config, @dirs);
    upload($config);

    $comics->load_social_media_posters();
    unless (@{$comics->{social_media_posters}}) {
        croak('No social media posters configured');
    }

    my @output = $comics->post_todays_comic_to_social_media();
    _print_all(@output);
    return;
}


sub _print_all {
    foreach my $line (@ARG) {
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
        _print_all("loading settings from $file");
        my $type = File::Util::file_type($file);
        if (!$type) {
            croak("$file not found");
        }
        elsif ($type eq 'DIRECTORY') {
            croak("Cannot read settings from a directory ($file)");
        }
        $self->{settings}->load_str(File::Slurper::read_text($file));
    }

    return;
}


=head2 check_settings

Checks the given settings for validity and consistency. This is used for
global settings or settings for L<Comic>, checks and output modules need to
do their own checks on their own settings.

Arguments:

=over 4

=item * B<%settings> configuration settings to check.

=back

=cut

sub check_settings {
    my (%settings) = @ARG;

    foreach my $prefix (qw(NoTranscriptPrefix TranscriptOnlyPrefix)) {
        if (exists $settings{'LayerNames'}{$prefix} && $settings{'LayerNames'}{$prefix} eq '') {
            croak("$prefix cannot be empty");
        }
    }

    my $not = $settings{'LayerNames'}{'NoTranscriptPrefix'};
    my $only = $settings{'LayerNames'}{'TranscriptOnlyPrefix'};
    if ($only && $not && $only =~ m{^$not}x) {
        croak('TranscriptOnlyPrefix and NoTranscriptPrefix cannot overlap');
    }

    return;
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
    # The configuration file uses a hash of module name to settings for
    # modules. This makes for a nice way to configure the modules. A JSON
    # hash is per definition unordered, but we need the modules in the right
    # order as some depend on the output of others.
    #
    # There are two solutions to this problem: push it onto the user to know
    # and define dependencies, or figure out the dependencies in code.
    #
    # Pushing it onto the user is certainly not terribly user-friendly. It
    # also makes for ugly and clumsy configuration files. For example,
    # changing the configuration to an array would have added another layer
    # in the configuration file, making it ugly to edit. Adding an "order"
    # member in each generator configuration makes it hard to insert modules
    # (have to adjust all later numbers) and also pushes the need to know
    # the module dependencies onto the user. Adding an extra array of the
    # generator names just for ordering purposes separates order and actual
    # settings of generators far away from each other.
    #
    # The current solution moves the knowledge or module ordering (not
    # really dependencies) into Comic::Out::Generator. This has some
    # limitations in that it requires changing Comic::Out::Generator way too
    # often:
    # - when hooking up a new (e.g., 3rd party) module
    # - if you want to change the order for whatever reason
    #
    # With the limited amount of 3rd party modules, anything clever here is
    # probably a YAGNI, hence stick with the simplest thing that could
    # possibly work and doesn't force the user to deal with internals like
    # generator dependencies.
    my ($self) = @ARG;

    my %order = Comic::Out::Generator::order();
    my @generators = $self->_load_modules($Comic::Settings::GENERATORS, sub { return () }, 'No output generators configured');
    @{$self->{generators}} = sort { $order{ref $a} <=> $order{ref $b} } @generators;
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

    my $actual_settings = $self->{settings}->clone();
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
        my $module = Comic::Modules::load_module($name, $module_args);
        push @loaded, $module if ($module);
    }

    if (!@loaded && $error_if_no_modules) {
        # No modules configured or found by default, but needs some --- bail out.
        croak($error_if_no_modules);
    }

    _print_all("$type modules loaded: ", _pretty_refs(@loaded));
    return @loaded;
}


sub _pretty_refs {
    # removes hash code from module, e.g., Comic::Out::QrCode(HASH=0x...) -> Comic::Out::QrCode
    my (@things) = @ARG;

    my @refs;
    foreach my $thing (@things) {
        push @refs, ref $thing;
    }
    return join ', ', @refs;
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
    e.g., in the C<see> comic metadata to refer to another comic. Later
    code checking paths may or may not be aware of the current directory and
    hence not find referenced files.

=back

=cut

sub collect_files {
    my (@files_or_dirs) = @ARG;

    my @collection;
    foreach my $fod (@files_or_dirs) {
        _print_all("loading comics from $fod");
        my @types = File::Util::file_type($fod);
        if (join(q{,}, @types) =~ m{DIRECTORY}) {
            File::Find::find(
                sub {
                    my $name = $File::Find::name;
                    push @collection, $name if ($name =~ m/[.]svg$/);
                },
                $fod);
        }
        else {
            push @collection, $fod;
        }
    }
    return @collection;
}


=head2 run_all_checks

Runs all configured checks for all loaded Comics that have been modified.

Returns a hash of comic source file name to any warnings and messages from checking the comics.

=cut

sub run_all_checks {
    my ($self) = @ARG;

    my $messages_file = $self->{settings}->{settings}->{$Comic::Settings::CHECKS}->{persistMessages};
    my %messages = _load_messages($messages_file);

    foreach my $comic (@{$self->{comics}}) {
        # Don't check comics if they are up to date, i.e., the input file
        # has not changed since last run. This works as all checks only look
        # at one comic at a time.
        # For my 350 comics, this cuts comic processing time from ~95s to
        # ~46s when only one comic has changed, and to ~41s if nothing has
        # changed.
        if ($self->_up_to_date($comic)) {
            # Restore cached messages to the comic.
            my $messages = $messages{$comic->{srcFile}};
            $comic->warning($_) foreach (@{$messages});
        }
        else {
            # Ask each comic to run its checks, which may be the ones configured
            # globally or overridden in the comic.
            delete $messages{$comic->{srcFile}};
            $comic->check();
            if (@{$comic->{warnings}}) {
                $messages{$comic->{srcFile}} = $comic->{warnings};
            }
        }
    }

    _save_messages($messages_file, \%messages);
    return %messages;
}


sub _load_messages {
    my ($filename) = @ARG;

    my $json = {};
    eval {
        my $text = File::Slurper::read_text($filename);
        $json = decode_json($text);
    } or do {
        # Ignore eval errors: File didn't exist or wasn't valid JSON; guess we don't have old messages.
    };
    return %{$json};
}


sub _save_messages {
    my ($filename, $messages) = @ARG;

    my $json = encode_json($messages);
    my ($file, $dirs) = fileparse($filename);
    File::Path::make_path($dirs);
    File::Slurper::write_text($filename, $json);
    return;
}


sub _up_to_date {
    my ($self, $comic) = @ARG;

    foreach my $gen (@{$self->{generators}}) {
        foreach my $language($comic->languages()) {
            return 0 unless ($gen->up_to_date($comic, $language));
        }
    }
    return 1;
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
        foreach my $name ( keys %{$comic->{checks}}) {
            my $check = $comic->{checks}->{$name};
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

Run all the configured uploaders to upload generated content somewhere and
returns the messages they returned.

=cut

sub upload_all_comics {
    my ($self) = @ARG;
    my @messages;

    my @comics = _todays_comics(@{$self->{comics}});
    foreach my $uploader (@{$self->{uploaders}}) {
        push @messages, $uploader->upload(@comics);
    }

    return @messages;
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


=head2 next_publish_day

Finds the next publish day from today and returns that date in ISO8601
format. Publish days are taken from the C<Comic::Check::Weekday>
configuration. If called on a day where a comic usually gets published,
it picks that day. For example, when publishing on Fridays, when called on
Friday 1, will pick Friday 1. When publishing on Mondays and Fridays,
and called on Saturday 2, will pick Monday 4.

=cut

sub next_publish_day {
    my ($self) = @ARG;
    Readonly my $DAYS_PER_WEEK => 7;

    no autovivification;
    my $weekday_settings = $self->{settings}->{settings}->{Checks}->{'Comic::Check::Weekday'};
    use autovivification;
    croak('Comic::Check::Weekday configuration not found') if (!$weekday_settings);

    my @publish_days;
    if (ref $weekday_settings eq '') {
        @publish_days = ($weekday_settings);
    }
    elsif (ref $weekday_settings eq 'ARRAY') {
        @publish_days = @{$weekday_settings};
        croak('Comic::Check::Weekday configuration is empty') if (!@{$weekday_settings});
    }
    else {
        croak('Comic::Check::Weekday must be scalar or array');
    }

    my $now = DateTime->now();
    my @future_comics = grep {
        $_->{meta_data}->{published}->{when} || '1000-01-01' ge $now->format_cldr('yyyy-MM-dd')
    } @{$self->{comics}};
    my $next_date;
    my $date_taken = 1;
    while ($date_taken) {
        my $todays_week_day = $now->day_of_week();
        my $next_pub_in = $DAYS_PER_WEEK;
        foreach my $pub_week_day (@publish_days) {
            my $next = $pub_week_day - $todays_week_day;
            $next += $DAYS_PER_WEEK if ($next < 0);
            $next_pub_in = $next if ($next < $next_pub_in);
        }

        my $target = $now + DateTime::Duration->new(days => $next_pub_in);
        $next_date = $target->format_cldr('yyyy-MM-dd');

        $date_taken = 0;
        foreach my $comic (@future_comics) {
            $date_taken = 1 if ($comic->{meta_data}->{published}->{when} eq $next_date);
        }
        if ($date_taken) {
            $now = $now + DateTime::Duration->new(days => 1);
        }
    }

    return $next_date;
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
