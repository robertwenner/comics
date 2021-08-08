package Comic::Check::Spelling;

use strict;
use warnings;
use utf8;
use Carp;
use English '-no_match_vars';
use String::Util 'trim';
use Text::Aspell;

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=for stopwords Inkscape Wenner merchantability perlartistic MetaEnglish EnglishBackground englishtest english

=head1 NAME

Comic::Check::Spelling - Checks spelling in the given comic.

=head1 SYNOPSIS

    my %ignore = (
        "English" => ["typo"],
    );
    my $check = Comic::Check::Spelling->new("ignore" => \%ignore);
    foreach my $comic (@all_comics) {
        $check->check($comic);
    }

=head1 DESCRIPTION

This flags comics that contain spelling errors. Inkscape has a built-in
spell check, but that does not check meta data. As opposed to this Check,
Inkscape also doesn't know the language of the text, making it hard to use
on anything but the system language. Inkscape's spell check doesn't check
automatically.

Comic::Check::Spelling does not keep state and can be reused between comics.

=cut


=head1 SUBROUTINES/METHODS

=head2 new

Creates a new Comic::Check:Spelling that works on each Comic.

Parameters:

=over 4

=item * B<%ignore> Hash of language to ignored words list. Languages need to
    be lowercase and start with a capital letter. Ignored words are not
    case-sensitive.

=back

=cut


sub new {
    my ($class, %args) = @ARG;
    my $self = $class->SUPER::new();
    $self->{ignore} = {};
    if ($args{ignore}) {
        unless (ref $args{ignore} eq ref {}) {
            croak('Ignore list must be a hash of language to ignored word(s)');
        }
        foreach my $language (keys %{$args{ignore}}) {
            my $ignore = $args{ignore}{$language};
            if (ref $ignore eq ref []) {
                %{$self->{ignore}{$language}} = map { lc $_ => 1 } @{$ignore};
            }
            elsif (ref $ignore eq ref '') {
                $self->{ignore}{$language}{lc $ignore} = 1;
            }
            else {
                croak('Ignore words must be array or single value');
            }
        }
    }
    $self->{dictionaries} = ();
    return $self;
}


=head2 check

Checks the given Comic's spelling.

This Check considers all layers in the given comic, where the layer name
includes the language name, with an upper case first character and the rest
in lower case. For example, when checking english spelling, this Check will
look at layers named "English", "MetaEnglish", and "EnglishBackground", but
not "englishtest" or "ENGLISH".

Parameters:

=over 4

=item * B<$comic> Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    my %codes = $comic->language_codes();
    foreach my $language ($comic->languages()) {
        my $code = $codes{$language};
        if ($self->_has_dictionary($code)) {
            $self->_check_metadata($comic, $language);
            $self->_check_layers($comic, $language);
        }
        else {
            $comic->warning("No $language ($code) aspell dictionary installed, skipping spell check");
        }
    }
    return;
}


sub _has_dictionary {
    my ($self, $code) = @ARG;

    if (!$self->{dictionaries}) {
        my $aspell = Text::Aspell->new();
        foreach my $line ($aspell->list_dictionaries()) {
            my @fields = split /:/, $line;
            my $found = $fields[0];
            if (length($found) == 2) {
                my $dictionary = Text::Aspell->new();
                $dictionary->set_option('lang', $found);
                ${$self->{dictionaries}}{$found} = $dictionary;
            }
        }
    }

    return defined ${$self->{dictionaries}}{$code};
}


sub _check_metadata {
    my ($self, $comic, $language) = @ARG;

    # Look at the comic's meta data top level keys, and if they are hashes (e.g.,
    # date and author are not), look for language keys right underneath.
    # This assumes that languages always appear at that level.
    foreach my $key (sort keys %{$comic->{meta_data}}) {
        next unless (ref $comic->{meta_data}{$key} eq ref {});

        my $value = $comic->{meta_data}{$key}{$language};
        next unless $value;

        my @texts;
        if (ref $value eq ref '') {
            @texts = ($value);
        }
        elsif (ref $value eq ref []) {
            @texts = @{$value};
        }
        elsif (ref $value eq ref {}) {
            @texts = (keys %{$value}, values %{$value});
        }
        else {
            # Something in the metadata is really messed up.
            $comic->keel_over('Cannot spell check a ' . ref $value);
        }

        foreach my $text (@texts) {
            $self->_check_text($comic, $language, "$language metadata '$key'", $text);
        }
    }
    return;
}


sub _check_layers {
    my ($self, $comic, $language) = @ARG;

    my $normalized_language = ucfirst lc $language;
    my @layers = $comic->get_all_layers();
    foreach my $layer (@layers) {
        my $label = $layer->{'inkscape:label'};
        next unless ($label =~ $normalized_language);

        foreach my $text ($comic->texts_in_layer($label)) {
            $self->_check_text($comic, $language, "layer $label", $text);
        }
    }
    return;
}


sub _check_text {
    my ($self, $comic, $language, $where, $text) = @ARG;

    my %codes = $comic->language_codes();
    my $code = $codes{$language};
    my $dictionary = ${$self->{dictionaries}}{$code};

    foreach my $word (_cut_into_words($text)) {
        next if (defined ($self->{ignore}{$language}{lc $word}));
        unless ($dictionary->check($word)) {
            $comic->warning("Misspelled in $where: '$word'?");
        }
    }
    return;
}


sub _cut_into_words {
    my @texts = @ARG;

    my @words;
    foreach my $text (@texts) {
        foreach my $word (split /\P{alpha}/, $text) {
            $word = trim($word);
            push @words, $word if ($word);
        }
    }
    return @words;
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
