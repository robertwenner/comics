package Comic::Check::Spelling;

use strict;
use warnings;
use utf8;
use Carp;
use English '-no_match_vars';
use String::Util 'trim';
use Text::SpellChecker;
use File::Slurper;

use Comic::Check::Check;
use base('Comic::Check::Check');

use version; our $VERSION = qv('0.0.3');


=encoding utf8

=for stopwords Inkscape Wenner merchantability perlartistic MetaEnglish BackgroundEnglish Englishtest


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

=item * B<%user_dictionary> Hash of language to file name. The file needs to
    have a word per line. These words are ignored in that language.

=item * B<$print_unknown_xml> Whether to print the unknown words in
    XML-syntax, like C<&quot;unknown&quot;> to easily copy into the comic's
    ignore list when editing the source directly in a text editor.

=item * B<$print_unknown_quoted> Whether to print the unknown words quoted,
    like C<"unknown"> to easily copy into the comic's ignore list when
    editing the source comic file in an SVG or XML editor.

=item * B<$print_unknown_lines> Whether to print the unknown words one a line
    to easily copy into a global ignore list.

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
    if ($args{user_dictionary}) {
        unless (ref $args{user_dictionary} eq ref {}) {
            croak('user_dictionary must be a hash of language to words file');
        }
        foreach my $language (keys %{$args{user_dictionary}}) {
            my $file_name = $args{user_dictionary}{$language};
            eval {
                foreach my $line (File::Slurper::read_lines($file_name)) {
                    $line =~ s{^\s+}{}mgx;
                    $line =~ s{\s+$}{}mgx;
                    push @{$self->{ignore}{$language}}, $line if ($line);
                }
                1;
            }
            or croak("Error reading $language user_dictionary from $file_name: $EVAL_ERROR");
        }
    }

    $self->{print_unknown_xml} = $args{print_unknown_xml};
    $self->{print_unknown_quoted} = $args{print_unknown_quoted};
    $self->{print_unknown_lines} = $args{print_unknown_lines};

    $self->{dictionaries} = ();
    return $self;
}


=head2 check

Checks the given Comic's spelling.

This Check considers all layers in the given comic, where the layer name
ends in  the language name (with an upper case first character and the rest
in lower case). For example, when checking English spelling, this Check will
look at layers named "English", "MetaEnglish", and "BackgroundEnglish", but
not "Englishtest" or "ENGLISH".

If the dictionaries for a language are not installed, all words will be
flagged as typos.

Parameters:

=over 4

=item * B<$comic> Comic to check.

=back

=cut

sub check {
    my ($self, $comic) = @ARG;

    my %codes = $comic->language_codes();
    foreach my $language ($comic->languages()) {
        $self->{unknown_words} = {};
        $self->{complained_about} = {};

        $self->_check_metadata($comic, $language);
        $self->_check_layers($comic, $language);

        foreach my $msg (sort keys %{$self->{complained_about}}) {
            my $count = $self->{complained_about}{$msg};
            $msg .= " ($count times)" if ($count > 1);
            $self->warning($comic, $msg);
        }

        if (keys %{$self->{unknown_words}}) {
            $self->_unknown_word_list($comic, $language, $self->{print_unknown_xml}, '&quot;', ', ');
            $self->_unknown_word_list($comic, $language, $self->{print_unknown_quoted}, q{"}, ', ');
            $self->_unknown_word_list($comic, $language, $self->{print_unknown_lines}, '', "\n");
        }
    }
    return;
}


sub _check_metadata {
    my ($self, $comic, $language) = @ARG;

    foreach my $key (sort keys %{$comic->{meta_data}}) {
        # Look at the comic's meta data top level keys, and if they are
        # hashes (e.g., date and author are not), look for language keys
        # right underneath. This assumes that languages always appear at
        # that level. If this is is not the case, ignore the key as we
        # wouldn't know in which language to spell-check it anyway.
        next unless (ref ${$comic->{meta_data}}{$key} eq 'HASH');

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

    # remove URLs, no point in spellchecking them
    $text =~ s{https?://\S+}{}mgi;

    my $checker = Text::SpellChecker->new(lang => $code, text => $text);
    while (my $word = $checker->next_word()) {
        next if (defined ($self->{ignore}{$language}{lc $word}));

        ${$self->{complained_about}}{"Misspelled in $where: '$word'?"}++;
        ${$self->{unknown_words}}{$word}++;
    }
    return;
}


sub _unknown_word_list {
    my ($self, $comic, $language, $check, $quote, $separator) = @ARG;

    if ($check) {
        my $msg = "Unknown $language word(s):\n";
        foreach my $unknown (sort keys %{$self->{unknown_words}}) {
            $msg .= "$quote$unknown$quote$separator";
        }
        $msg =~ s/$separator$//;
        $self->warning($comic, $msg);
    }
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

Copyright (c) 2021 - 2022, Robert Wenner C<< <rwenner@cpan.org> >>.
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
