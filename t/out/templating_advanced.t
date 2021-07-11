use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Template;

# Exploratory test for advanced templating, like a list of contributors for a comic.


__PACKAGE__->runtests() unless caller;


my $template_en;
my $template_de;
my $translator_template;


sub set_up : Test(setup) {
    $template_en = <<'TEMPL';
[% DEFAULT contrib = 0 %]
[% IF contrib && contrib.size %]
    <p style="contributors">With help from
        [% FOREACH c IN contrib %]
            [% c != contrib.first && c == contrib.last ? ' and ' : '' %][% c %][% contrib.defined(2) ? ', ' : '' %]
        [% END %]
    </p>
[% END %]
TEMPL

    $template_de = <<'TEMPL';
[% DEFAULT contrib = 0 %]
[% IF contrib && contrib.size %]
    <p style="contributors">Mit Ideen von
        [% FOREACH c IN contrib %][% c != contrib.first && c == contrib.last ? ' und ' : '' %][% c != contrib.first && c != contrib.last ? ', ' : '' %][% c %][% END %]
    </p>
[% END %]
TEMPL

    $translator_template = <<'TRANS';
[% DEFAULT translator.$Language = 0 %]
[% IF translator.$Language %]
    <p style="contributors">Übersetzt von [% translator.$Language %].</p>
[% END %]
TRANS
}


sub templatize {
    my ($template, %vars) = @_;

    my %options = (
        STRICT => 1,
        PRE_CHOMP => 0, # removes space in beginning of a directive
        POST_CHOMP => 2, # removes spaces after a directive
        ENCODING => 'utf8',
    );
    my $templ = Template->new(%options) || fail("Could not create template: $!");
    my $output;
    $templ->process(\$template, \%vars, \$output) || die("Template error: " . Template->error());
    return $output;
}


sub contributor_credit_en_none : Tests {
    like(templatize($template_en),
         qr{\A\s*\z}xim);
}


sub contributor_credit_en_empty : Tests {
    like(templatize($template_en, 'contrib' => []),
         qr{\A\s*\z}xim);
}


sub contributor_credit_en_one : Tests {
    like(templatize($template_en, 'contrib' => ["Mark D"]),
         qr{With\s+help\s+from\s+Mark\s+D}xim);
}


sub contributor_credit_en_two : Tests {
    like(templatize($template_en, 'contrib' => ['Mark D', 'Mike K']),
         qr{With\s+help\s+from\s+Mark\s+D\s+and\s+Mike\s+K}xim);
}


sub contributor_credit_en_many : Tests {
    like(templatize($template_en, 'contrib' => ['Mark D', 'Mike K', 'My Self']),
        qr{With\s+help\s+from\s+Mark\s+D,\s+Mike\s+K,\s+and\s+My\s+Self}xim);
}


sub contributor_credit_de_none : Test {
    like(templatize($template_de),
         qr{\A\s*\z}xim);
}


sub contributor_credit_de_empty : Tests {
    like(templatize($template_de, 'contrib' => []),
         qr{\A\s*\z}xim);
}


sub contributor_credit_de_one : Test {
    like(templatize($template_de, 'contrib' => ["Mark D"]),
         qr{Mit\s+Ideen\s+von\s+Mark\s+D}xim);
}


sub contributor_credit_de_two : Test {
    like(templatize($template_de, 'contrib' => ['Mark D', 'Mike K']),
        qr{Mit\s+Ideen\s+von\s+Mark\s+D\s+und\s+Mike\s+K}xim);
}


sub contributor_credit_de_many : Test {
    like(templatize($template_de, 'contrib' => ['Mark D', 'Mike K', 'mir']),
        qr{Mit\s+Ideen\s+von\s+Mark\sD,\s+Mike\s+K\s+und\s+mir}xim);
}


sub translator_ok : Tests {
    my %vars = (
        'Language' => 'Deutsch',
        'translator' => {
            'Deutsch' => 'mir',
        },
    );
    like(templatize($translator_template, %vars), qr{Übersetzt von mir}im);
}


sub translator_none : Tests {
    my %vars = (
        'Language' => 'Deutsch',
    );
    like(templatize($translator_template, %vars), qr{^\s*$}m);
}
