package Comic::Upload::Rsync;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Tie::IxHash;
use File::Rsync;

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


=encoding utf8

=for stopwords Wenner merchantability perlartistic rsync


=head1 NAME

Comic::Upload::Rsync - upload files with rsync. This can be used to
upload to a web server, for example.


=head1 SYNOPSIS

This class cannot be used directly.


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
    }

The C<source> defines the source directory that will be copied.

The C<destination> says where to rsync the files to. This can be another
directory or host name or whatever else C<rsync> accepts on the command
line.

C<keyfile> is optional. When given, it's passed to C<rsync> as an ssh option
like this: C<--rsh="ssh -i path/to/your/ssh-key.id_rsa">.

C<options> is an optional array of no-arg options for rsync. See the rsync
man page for details. Defaults to checksum, compress, delete, recursive,
times, and update if not given.

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

    $self->{settings} = \%settings;
    $self->{settings}->{options} = \@DEFAULT_RSYNC_OPTIONS unless ($options);
    return $self;
}


=head2 upload

Uploads files according to the settings passed to the constructor.

=cut

sub upload {
    my ($self) = @ARG;

    my %options;
    # Preserve options order, first or easier testing, second in case it
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
    return;
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
