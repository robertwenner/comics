package Comic::Upload::Rsync;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Tie::IxHash;
use File::Rsync;
use HTTP::Tiny;

use version; our $VERSION = qv('0.0.3');

use Comic::Upload::Uploader;
use base('Comic::Upload::Uploader');

use Readonly;
Readonly my @DEFAULT_RSYNC_OPTIONS => qw(
    checksum
    compress
    delete
    recursive
    times
    update
);
Readonly my $DEFAULT_CHECK_DELAY => 10; # seconds
Readonly my $DEFAULT_CHECK_TRIES => 30; # times


=encoding utf8

=for stopwords Wenner merchantability perlartistic rsync


=head1 NAME

Comic::Upload::Rsync - upload files with rsync. This can be used to
upload to a web server, for example.


=head1 SYNOPSIS

    my $rsync = Comic::Upload::Rsync->new({
        "sites" => [
            {
                "source" => "generated/web/english",
                "destination" => "you@your-host.example.com:english/",
            },
            {
                "source" => "generated/web/deutsch",
                "destination" => "you@your-host.example.com:deutsch/",
            },
        ],
        "keyfile" => "path/to/your/ssh-key.id_rsa",
    });
    $rsync->upload(@comics);


=head1 DESCRIPTION

Uses the C<rsync> tool (which must be installed) to upload changed files.


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Upload::Rsync.

Parameters:

=over 4

=item * B<%settings> Hash reference with settings, as below.

=back

The passed settings must be a hash reference like this:

    {
        "sites" => [
            {
                "source" => "generated/web/english",
                "destination" => "you@your-host.example.com:english/",
            },
            {
                "source" => "generated/web/deutsch",
                "destination" => "you@your-host.example.com:deutsch/",
            },
        ],
        "keyfile" => "path/to/your/ssh-key.id_rsa",
        "options" => ["recursive"],
        "check" => {
            "delay" => 10,
            "tries" => 30,
        },
    }

The C<source> defines the source directory that will be copied.

The C<destination> says where to rsync the files to. This can be another
directory or host name or whatever else C<rsync> accepts on the command
line.

C<keyfile> is optional. When given, it's passed to C<rsync> as an ssh option
like this: C<--rsh="ssh -i path/to/your/ssh-key.id_rsa">.

C<options> is an optional array of no-argument options for rsync. See the
rsync man page for details. Defaults to checksum, compress, delete, recursive,
times, and update if not given.

C<check> (optional) means to check that the URLs of the comic(s) passed to
the C<upload> function are live in each of the comic's languages. If the
URLs are not available, wait C<delay> seconds and try again, up to C<tries>
times. If the URLs are still not reachable, the upload is considered failed
and this module C<croak>s. This is meant to prevent later modules from
posting dead links to social media when a sluggish web server hasn't yet
made the new comic available. The above example will try to load the Comic's
URLs up to 30 times, with a delay of 10 seconds between tries, for a total
of 5 minutes, croaking if the URL is not available by then. If C<check> is
not given, the web server is not queried.

=cut

sub new {
    my $class = shift @ARG;
    my $self = bless{}, $class;

    $self->_croak('settings hash missing') unless(@ARG);
    $self->_croak('settings must be a hash') unless (@ARG % 2 == 0);

    my %settings = @ARG;
    $self->_croak('sites missing in settings') unless ($settings{sites});
    $self->_croak('sites must be an array') unless (ref $settings{sites} eq 'ARRAY');
    $self->_croak('sites must not be empty') if (@{$settings{sites}} == 0);

    my $options = $settings{options};
    if ($options) {
        $self->_croak('options must be an array') if (ref $options ne 'ARRAY');
    }

    my $check = $settings{check};
    if ($check) {
        $self->_croak('check must be a hash') if (ref $check ne 'HASH');
        $check->{'delay'} = $DEFAULT_CHECK_DELAY unless ($check->{'delay'});
        $self->_croak('check.delay must be a positive number') if ($check->{delay} !~ m{^\d+$}x);
        $check->{'tries'} = $DEFAULT_CHECK_TRIES unless ($check->{'tries'});
        $self->_croak('check.tries must be a positive number') if ($check->{tries} !~ m{^\d+$}x);
    }

    $self->{settings} = \%settings;
    $self->{settings}->{options} = \@DEFAULT_RSYNC_OPTIONS unless ($options);
    return $self;
}


=head2 upload

Uploads files according to the settings passed to the constructor.

Parameters:

=over 4

=item * B<@comics> Latest (today's) comics. Used for checking that the web
    server has updated them, if a C<check_timeout> is configured.

=back

=cut

sub upload {
    my ($self, @comics) = @ARG;

    my %options;
    # Preserve options order, first for easier testing, second in case it
    # matters for user defined options.
    ## no critic(Miscellanea::ProhibitTies)
    tie %options, 'Tie::IxHash';
    ## use critic
    foreach my $o (@{$self->{settings}->{options}}) {
        $options{$o} = 1;
    }
    if ($self->{settings}->{keyfile}) {
        # Do not quote key file, as the whole thing is quoted and probably
        # passed as-is to rsync in C code, not involving a shell.
        $options{'--rsh'} = "ssh -i $self->{settings}->{keyfile}";
    }

    my $rsync = File::Rsync->new();
    my $problems;
    foreach my $site (@{$self->{settings}->{sites}}) {
        my $source = ${$site}{source};
        $self->_croak('source missing') unless ($source);
        my $destination = ${$site}{destination};
        $self->_croak('destination missing') unless ($destination);

        unless ($rsync->exec(src => $source, dest => $destination, %options)) {
            $problems .= 'rsync error (' . $rsync->realstatus() . ") for \n";
            $problems .= $rsync->lastcmd() . "\n";
            $problems .= join "\n", $rsync->out();
            $problems .= join "\n", $rsync->err();
        }
    }

    $self->_croak($problems) if ($problems);

    if ($self->{settings}->{check}) {
        foreach my $comic (@comics) {
            foreach my $language ($comic->languages()) {
                $self->_check_url($comic->{url}{$language});
            }
        }
    }

    return;
}


sub _check_url {
    my ($self, $url) = @ARG;

    my $tries = 0;
    while (1) {
        my $response = HTTP::Tiny->new->get($url);
        last if ($response->{success});

        if ($tries == $self->{settings}->{check}->{tries}) {
            $self->_croak("Could not get $url");
        }
        $tries++;
        _sleep($self->{settings}->{'check'}->{'delay'});
    }
    return;
}


sub _sleep {
    # uncoverable subroutine
    my ($seconds) = @ARG; # uncoverable statement
    sleep $seconds; # uncoverable statement
    return; # uncoverable statement
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

Copyright (c) 2021 - 2023, Robert Wenner C<< <rwenner@cpan.org> >>.
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
