package Comic::Out::Generator;

use strict;
use warnings;
use English '-no_match_vars';
use Carp;
use Comic::Modules;

use version; our $VERSION = qv('0.0.3');


=for stopwords html Wenner merchantability perlartistic png html svg acyclic yaml toml ebook


=head1 NAME

Comic::Out::Generator - base class for all Comic modules that produce output.

=head1 SYNOPSIS

Should not be used directly.

=head1 DESCRIPTION

All Comic::Out modules should derive from this class.

Generators are configured in the configuration file. They are called in the
order they are defined in.

A generator can use one or both methods of generating output:

=over 4

=item * for each comic (in the C<generate> method), like generating a PNG
image or HTML page for the comic

=item * for all comics together (C<generate_all> method), like an overview
page

=back

Generators may ignore either of these methods; the default implementation
does nothing. (Of course, if you don't override at least one of these
methods, your generator does not generate anything.)

When a comic is processed, first all configured Generators are asked to
generate per-comic output (C<generate> method). When that is done, all
Generators are asked to generate output for all comics (C<generate_all>
method). That way the C<generate_all> method can access comic data generated
by previous generators, for example, an overview page can use the URL that a
per-comic html page generator created and stored in each Comic.

=cut


=head1 SUBROUTINES/METHODS

=head2 order

Static method that returns a hash of generator module names to the order in
which they should run.

Background: Generators are given as a JSON object in the configuration file.
A JSON object is a like a hash, unordered by definition (see
L<RFC8250|https://datatracker.ietf.org/doc/html/rfc8259>, section 4). But
generators may depend on the output of other generators. For example,
L<Comic::Out::QrCode> needs to know what URL to encode.

How to get around this?


=head3 Tie::IxHash

Try to force an ordered hash for the generators.

This makes it easy to use for comic authors: they just order the hash as
needed.

It also is a bad hack, messing with the internals of probably JSON parsing,
and anybody who knows JSON would be surprised of this behavior.


=head3 Array of objects

Instead of using a hash in the configuration file, use an array instead,
which is always ordered.

    "Out": [
        {
            "Comic::Out::...": {
                ...
            }
        },
        ...

On the plus side, this easy to understand for comic authors and easy to
parse in the code.

But it introduces an extra level in he configuration file, which may not be
very intuitive to people not used to JSON. It would also be inconsistent
compared to the C<Commic::Checks::Check> configuration (array vs object).


=head3 Order implicitly defined

This is the current approach: define the order of generators in the code.
This way comic authors don't need to know about such details. The drawback
is that you cannot hook in new modules without changing the code in this
C<order> function. This could be fixed by allowing people to override the
order in the configuration file.


=head3 Order explicitly configured

Put a new key, e.g., C<position>, in each generator configuration that
defines its position in the order.

    "Out": {
        "Comic::Out::...": {
            "position": 1,
            ...
        },
        ...

Pros: easy to code, somewhat easy to configure (until you have to insert a
module and move all others one down). Still forces comic authors to know
which generator depends on which other generators. If a generator has no
position or if two generators share a position, C<croak>.


=head3 Objects plus an ordering array

Keep the objects for each generator, and add an array that defines the order.

    "Out": {
        "order": ["Comic::Out::Foo", "Comic::Out::Bar"],

        "Comic::Out::Foo": {
            ...
        },
        "Comic::Out::Bar": {
            ...
        },
        ...

This should make for simple code, but comic authors may have to scroll a lot
between order and actual generator definition. This also looks clumsy. Comic
authors still need to know ordering details. This could be made easier by
providing a default order in the code an let the user override it if he
needs to (i.e., when hooking in non-standard modules).


=head3 Explicit dependencies

Each generator defines what other generator's output it needs instead of a
fixed position number.

    "Out": {
        "Comic::Out::Foo": {
            "after": "Comic::Out::Bar",
            ...
        },
        ...

Problems: where do generators without an C<after> go? In the end? In the
beginning? Could be hard to configure, and the code has to build a direct
acyclic graph like a build tool --- more complexity than I want here.

This gets more complicated with multiple dependencies: if both
L<Comic::Out::Png> and L<Comic::Out::QrCode> depend on
L<Comic::Out::SvgPerLanguage> which should go first? Does it matter? The
other way around: Should L<Comic::Out::Png> depend on
L<Comic::Out::SvgPerLanguage> or L<Comic::Out::Copyright>? Clearly if
L<Comic::Out::Copyright> is requested, <Comic::Out::Png> needs to depend on
that, otherwise on L<Comic::Out::SvgPerLanguage>.


=head3 Implicit dependency groups

Each generator belongs to a dependency group. The order of groups is
hard-coded. All generators in a group need to run before the next group can
start. Order within a group does not matter.

Groups could be:

=over 4

=item B<1)> group "from source": works with the original C<.svg> file (i.e.,
    L<Comic::Out::SvgPerLanguage>).

=item B<2)> group "svg modifier": modify the per-language C<.svg> files,
    e.g., L<Comic::Out::Copyright>) or a future watermarking module.

=item B<3)> group "graphic format": converts to another graphic format like
    C<.png> or C<.pdf>, or optimize existing images.

=item B<4)> group "basic context", provides the context in which to view the
    comics, like a web page, or a C<.pdf>, or an <.epub>.

=item B<5)> group "advanced context" for additional output like an archive
    web page, tag clouds, a PDF index, a RSS feed, and so on.

=item B<6)> group "everything else": stuff like L<Comic::Out::Sizemap> and
    L<Comic::Out::Backlog> that depends only on the "graphic format" group.

=back

Could be hard to insert new groups. Sounds like reinventing Gradle.


=head3 Different configuration file format

Throw out JSON... it's ugly anyway. But then again, YAML (white space based
format is hard to enter in Inkscape's proportional font input dialog) and TOML
(fancy C<.ini> files) are not much better. It would also be inconsistent to use
JSON in the Inkscape meta data and something else for the main configuration
file.

=cut

sub order {
    # Simple dependency description.
    my @order = (
        # Modules that modify the SVG in-memory.
        'Comic::Out::Copyright',
        # Modules that work with the Inkscape source files.
        'Comic::Out::SvgPerLanguage',
        # Convert svg files to different image file formats.
        'Comic::Out::Png',
        # Once we have an output image, include / embed that somewhere.
        'Comic::Out::HtmlComicPage',
        # Work with whatever embedding output format we generated in the previous step.
        'Comic::Out::HtmlLink',
        'Comic::Out::HtmlArchivePage',
        'Comic::Out::QrCode',
        'Comic::Out::Feed',
        'Comic::Out::Sitemap',
        # Other generators, potentially independent of previous ones.
        'Comic::Out::FileCopy',
        'Comic::Out::Sizemap',
        'Comic::Out::Backlog',
    );
    return map { +($order[$_] => $_) } 0 .. $#order;
}


=head2 new

Creates a new Comic::Out::Generator.

=cut

sub new {
    my ($class, %settings) = @ARG;
    my $self = bless{}, $class;

    %{$self->{settings}} = %settings;
    $self->{valid_ssettings} = {};

    return $self;
}


=head2 needs

Checks whether the passed settings have the given key and it refers to the
given type.

Parameters:

=over 4

=item B<$name> expected setting name.

=item B<$type> expected type. Pass '' for scalars, 'ARRAY' for arrays, or
    'HASH' for hashes. Pass 'hash-or-scalar' for settings that can be either
    a scalar or a hash.

    If the type is 'directory', this function makes sure it has a trailing
    slash for easy concatenation.

=back

=cut

sub needs {
    my ($self, $name, $type) = @ARG;

    $self->{valid_settings}->{$name} = 1;

    my $me = ref $self;
    croak("Must specify $me.$name") unless (exists $self->{settings}->{$name});
    my $value = $self->{settings}->{$name};

    my $expected_type = _type_name($type);
    my $actual_type = _type_name(ref $value);

    if ($type eq 'hash-or-scalar') {
        unless ($actual_type eq 'scalar' || $actual_type eq 'hash') {
            croak("$me.$name must be $expected_type, but is $actual_type");
        }
    }
    else {
        croak("$me.$name must be $expected_type but is $actual_type") unless ($expected_type eq $actual_type);

        if ($type eq 'directory') {
            ${$self->{settings}}{$name} .= q{/} unless (${$self->{settings}}{$name} =~ m{/$});
        }
    }

    return;
}


=head2 optional

Checks whether the passed settings have the given key and if the key exists,
makes sure that its value is the given type. Ignore if the key is missing.

Parameters:

=over 4

=item B<$name> setting name.

=item B<$type> expected type. Pass '' for scalars, 'ARRAY' for arrays, or
    'HASH' for hashes.

    Pass 'array-or-scalar' for a settig that can be either a scalar or an
    array. It will be converted in an array. If the argument was not given,
    that array will be empty. If the argument was a scalar, that will be the
    one and only array element. If the argument was an array, it is
    preserved as is.

=item B<$default_value> what to put in the settings if the key was not found.

=back

=cut

sub optional {
    my ($self, $name, $type, $default_value) = @ARG;

    $self->{valid_settings}->{$name} = 1;

    unless (exists $self->{settings}->{$name}) {
        $self->{settings}->{$name} = $default_value if ($default_value);
        return;
    }

    my $value = $self->{settings}->{$name};
    my $me = ref $self;
    my $expected_type = _type_name($type);
    my $actual_type = _type_name(ref $value);

    if ($type eq 'array-or-scalar') {
        if ($actual_type eq 'scalar') {
            ${$self->{settings}}{$name} = [$value];
        }
        elsif ( $actual_type eq 'array') {
            # ok, keep as is
        }
        else {
            croak("$me.$name must be $expected_type, but is $actual_type");
        }
    }
    else {
        croak("$me.$name must be $expected_type but is $actual_type") unless ($expected_type eq $actual_type);
    }

    return;
}


sub _type_name {
    my ($type) = @ARG;

    return 'array or scalar' if ($type eq 'array-or-scalar');
    return 'hash or scalar' if ($type eq 'hash-or-scalar');
    return 'scalar' if ($type eq '' || $type eq 'scalar' || $type eq 'directory');
    return 'array' if ($type eq 'ARRAY');
    return 'hash' if ($type eq 'HASH');
    return $type;
}


=head2 flag_extra_settings

Flag (croak) on any extra (invalid) settings passed to this Generator's
constructor. Valid settings are the names passed to C<needs> and C<optional>.

This method should be called at the end of child class constructors.

=cut

sub flag_extra_settings {
    my ($self) = @ARG;

    my $me = ref $self;
    foreach my $s (keys %{$self->{settings}}) {
        croak("$me: unknown setting '$s'") unless ($self->{valid_settings}->{$s});
    }

    return;
}


=head2 per_language_setting

Gets a setting from this Generator. If it's a scalar value setting, return
that. If it's a hash, return the element for the given language key.

=over 4

=item * B<$setting> name of the setting to get.

=item * B<$language> in which language to get the setting.

=back

=cut

sub per_language_setting {
    my ($self, $setting, $language) = @ARG;

    if (ref $self->{settings}->{$setting} eq '') {
        # one for all
        return $self->{settings}->{$setting};
    }
    else {
        # per-language hash
        return ${$self->{settings}->{$setting}}{$language};
    }
}


=head2 all_languages

Static method that gets all languages in the passed comics.

Parameters:

=over 4

=item * B<@comics> from what comics to get the languages.

=back

Returns an alphabetically sorted array of languages.

=cut

sub all_languages {
    my @comics = @ARG;

    my %languages;
    foreach my $comic (@comics) {
        foreach my $language ($comic->languages()) {
            $languages{$language}++;
        }
    }

    # return sort keys %languages is undefined behavior.
    my @languages = sort keys %languages;
    return @languages;
}


=head2 generate

Generate whatever output this Generator wants to generate for a given Comic.
This is called once for each comic to generate e.g., the comic's image or web page.

Parameters:

=over 4

=item * B<$comic> Comic to generate output for.

=back

=cut

sub generate {
    # Ignore.
    return;
}


=head2 generate_all

Generate output for all Comics.

This is called once with all comics to generate output that is not specific
for one comic, like an overview page.

Parameters:

=over 4

=item * B<@comics> Comics to generate output for.

=back

=cut

sub generate_all {
    # Ignore.
    return;
}


=head1 VERSION

0.0.3


=head1 DEPENDENCIES

Comic::Module.


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
