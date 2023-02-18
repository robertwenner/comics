package Comic::Out::Feed;

use strict;
use warnings;
use utf8;
use English '-no_match_vars';
use Carp;

use POSIX 'strftime';
use DateTime;
use DateTime::Format::RFC3339;

use version; our $VERSION = qv('0.0.3');

use Comic::Out::Template;
use Comic::Out::Generator;
use base('Comic::Out::Generator');

use Readonly;
Readonly my $FEED_ITEM_COUNT => 10;


=encoding utf8

=for stopwords Wenner merchantability perlartistic RSS notFor outdir


=head1 NAME

Comic::Out::Feed - Generates feeds. Meant for RSS or Atom feeds.


=head1 SYNOPSIS

    my $feed = Comic::Out::Feed->new(%settings);
    $feed->generate_all(@comics);


=head1 DESCRIPTION

Generates feeds (like Atom or RSS) for web the sites.

This approach relies on the used templates for the feed structure, which
means the web site author needs to know how to write feeds using Perl's
Template module, and the Feed package just populates them.

See L<Template> as well as L<RSS|https://en.wikipedia.org/wiki/RSS> and
L<Atom|https://en.wikipedia.org/wiki/Atom_(Web_standard)> on Wikipedia.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Out::Feed.

Parameters are taken from the C<Out.Feed> configuration:

=over 4

=item * B<%settings> Hash of settings, see below.

=back

The passed settings need to have output directory (outdir) and the feed type
(e.g., RSS or Atom) as top level keys. Under these keys, define the max (how
many comics should be included in the feed), the template file, and the
output file name.

For example:

    "outdir" => "generated",
    "RSS" => {
        "max" => 10,
        "template" => "templates/rss.templ",
        "outfile" => "rss.xml",
    },
    "Atom" => {
        "template" => "templates/atom.xml",
    }

This will generate both a RSS and an Atom feed, each showing the 10 latest
comics, and placing the feeds in F<rss.xml> and F<atom.xml> respectively.

Each feed will have 10 comics if no C<max> is given.

If no C<outfile> is given, the feed will be written to the feed name (in
lower case) with an C<.xml> extension (i.e., F<atom.xml> for the "Atom" feed
in the above example).

Output files will be placed in the given C<outdir> plus the language
(lowercase). For example, when called with C<outdir> as "generated/web", the
RSS feeds for English and German comics will be written to
F<generated/web/english/rss.xml> and F<generated/web/deutsch/rss.xml>.

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = $class->SUPER::new(%settings);

    $self->needs('outdir', 'directory');
    $self->optional('Atom', 'hash');
    $self->optional('RSS', 'hash');
    $self->flag_extra_settings();

    return $self;
}


=head2 generate_all

Generates the configured Feeds.

Parameters:

=over 4

=item * B<@comics> All Comics to consider. Only published comics will
    be passed to the template. If there are no (published) comics, the
    template will receive an empty list.

=back

Makes these variables available in the template:

=over 4

=item * B<@comics> array of all published comics in all languages.

=item * B<&notFor> function the template needs to call on each comic,
    passing the language. If that function returns C<true>, the comic should be
    skipped. This maps to C<&Comic::not_for>.

=item * B<$max> How many comics to include in the feed. This is the C<max>
    configuration value, so that the template doesn't need to hard-code
    configuration.

=item * B<$updated> the current data and time, in RFC3339 format, for the
    atom C<updated> element.

=back

=cut

sub generate_all {
    my ($self, @comics) = @ARG;

    my $now = _now();
    $now->set_time_zone(_get_tz());
    my $now_formatted = DateTime::Format::RFC3339->new()->format_datetime($now);
    my @languages = Comic::Out::Generator::all_languages(@comics);

    foreach my $type (keys %{$self->{settings}}) {
        next if ($type eq 'outdir');

        my $templates = $self->{settings}->{$type}->{'template'};
        my $max = $self->{settings}->{$type}->{'max'};
        $max = $FEED_ITEM_COUNT unless($max);
        my $outfile = $self->{settings}->{$type}->{'outfile'};
        $outfile = lc($type) . '.xml' unless($outfile);

        foreach my $language (@languages) {
            my @published = reverse sort Comic::from_oldest_to_latest grep {
                !$_->not_yet_published($language)
            } @comics;

            my $template = _get_template($templates, $language, $type);

            my %vars = (
                'comics' => \@published,
                'notFor' => \&Comic::not_published_on_in,
                'max' => $max,
                'updated' => $now_formatted,
            );

            my $feed = Comic::Out::Template::templatize("$type feed", $template, $language, %vars);
            Comic::write_file($self->{settings}->{outdir} . lc($language) . "/$outfile", $feed);
        }
    }
    return;
}


sub _now {
    # uncoverable subroutine
    return DateTime->now; # uncoverable statement
}


sub _get_tz {
    # uncoverable subroutine
    return strftime '%z', localtime; # uncoverable statement
}


sub _get_template {
    my ($templates, $language, $type) = @ARG;
    my $for_language = '';
    my $template;

    if (ref $templates eq ref {}) {
        $template = $templates->{$language};
        $for_language = " for $language";
    }
    else {
        $template = $templates;
    }

    if (!defined $template) {
        croak "Comic::Out::Feed: No $type template$for_language";
    }
    elsif (ref $template ne ref $language) {
        croak("Comic::Out::Feed: Bad $type template$for_language, must be file name or hash of language to file name");
    }

    return $template;
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

Copyright (c) 2016 - 2023, Robert Wenner C<< <rwenner@cpan.org> >>.
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
