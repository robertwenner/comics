package Comic::Out::FileCopy;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;
use File::Path qw(make_path);
# File::Copy does not support recursively copying directories.
# File::Copy::Recursive doesn't copy file meta information (like timestamps) and ignoring
# unchanged files.

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Generator;
use base('Comic::Out::Generator');

use Readonly;


=for stopwords Wenner merchantability perlartistic outdir cron Cygwin

=head1 NAME

Comic::Out::FileCopy - Copies files.

=head1 SYNOPSIS

    my $feed = Comic::Out::FileCopy->new(\%settings);
    $feed->generate_all(@comics);

=head1 DESCRIPTION

Copies files. This is meant for static files of a web page, like CSS or
static HTML content.

Having this functionality within the Comic modules makes it easy to call the
whole tool chain from the command line or cron jobs without having to add e.g.,
C<cp -r static/all/* generated/web/> after processing the comics and before
uploading the web page.

Does not copy files that have not been modified (according to the file
system). This is so that upload tools (e.g., C<rsync> without C<--checksum>
option) that work on file system time stamp can decide to also not upload
unchanged files again.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::FileCopy.

Parameters are taken from the C<Out.FileCopy> configuration:

=over 4

=item * B<$settings> Hash reference to settings.

=back

The passed settings need to have output directory (outdir) and

For example:

    "Out" => {
        "FileCopy" => {
            "outdir" => "generated/web",
            "from-all" => ["web/all"],
            "from-lamguage" => ["web/"],
        },
    }

Output files will be copied from the C<from-all> directory and the language
specific C<from-language> directories into the given C<outdir> plus the
(lowercase) language name.

For example, for the configuration above, files for English and German
comics will be written to F<generated/web/english/> and
F<generated/web/deutsch/> respectively. Files from F<web/all> will be copied
to both F<generated/web/english> and F<generated/web/deutsch>.

This module does I<not> support modifying copied files on the fly, e.g., to
update a published date or copyright year in an otherwise static HTML pages.
A generalized templating module could do that.

This module is just a wrapper around C<cp>, so you'll probably need to
install Cygwin tools on Windows.

=cut

sub new {
    my ($class, $settings) = @ARG;
    my $self = $class->SUPER::new();

    croak('No FileCopy configuration') unless ($settings->{FileCopy});
    %{$self->{settings}} = %{$settings->{FileCopy}};

    croak('Must specify FileCopy.outdir output directory') unless ($self->{settings}->{outdir});
    $self->{settings}->{outdir} .= q{/} unless ($self->{settings}->{outdir} =~ m{/$}x);

    if (!$self->{settings}->{'from-all'} && !$self->{settings}->{'from-language'}) {
        croak('Must specify at least one of from-all and from-language');
    }

    foreach my $from (qw(from-all from-language)) {
        $self->{settings}->{$from} = [];
        next unless ($settings->{FileCopy}->{$from});

        if (ref $settings->{FileCopy}->{$from} eq '') {
            push @{$self->{settings}->{$from}}, $settings->{FileCopy}->{$from};
        }
        elsif (ref $settings->{FileCopy}->{$from} eq 'ARRAY') {
            push @{$self->{settings}->{$from}}, @{$settings->{FileCopy}->{$from}};
        }
        else {
            croak("FileCopy.$from needs to be scalar or array");
        }
    }

    return $self;
}


=head2 generate_all

Copies the configured files and directories.

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my %languages;
    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $languages{$language}++;
        }
    }

    foreach my $language (sort keys %languages) {
        my $lc_lang = lc $language;
        my $to_dir = $self->{settings}->{outdir} . $lc_lang;
        File::Path::make_path($to_dir);

        foreach my $from (@{$self->{settings}->{'from-all'}}) {
            _cp("$from/*", $to_dir);
        }

        foreach my $from (@{$self->{settings}->{'from-language'}}) {
            _cp("$from/$lc_lang/*", $to_dir);
        }
    }

    return;
}


sub _cp {
    return _system('cp', '--archive', '--recursive', '--update', @ARG);
}


sub _system {
    # uncoverable subroutine
    return system @ARG; # uncoverable statement
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

The Unix C<cp> shell command.


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
