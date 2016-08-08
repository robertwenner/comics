use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub write_templ_en {
    my $template = <<'TEMPL';
[% IF contrib %]
    <p style="contributors">With help from
        [% FOREACH c IN contrib %]
            [% c != contrib.first && c == contrib.last ? ' and ' : '' %]
            [% c %][% contrib.defined(2) ? ', ' : '' %]
        [% END %]
    </p>
[% END %]
TEMPL
    return fake_template($template, @_);
}


sub write_templ_de {
    my $template = <<'TEMPL';
[% IF contrib %]
    <p style="contributors">Mit Ideen von
[% FOREACH c IN contrib %][% c != contrib.first && c == contrib.last ? ' und ' : '' %][% c != contrib.first && c != contrib.last ? ', ' : '' %][% c %][% END %]
    </p>
[% END %]
TEMPL
    return fake_template($template, @_);
}


sub fake_template {
    my ($template, $comic) = @_;
    no warnings qw/redefine/;
    local *Comic::_slurp = sub {
        return $template;
    };
    return $comic->_do_export_html($MockComic::ENGLISH);
}


sub contributor_credit_en_none : Tests {
    my $comic = MockComic::make_comic();
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_en_empty : Tests {
    my $comic = MockComic::make_comic($MockComic::JSON =>
        "&quot;contrib&quot;: []");
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_en_empty_quotes : Tests {
    my $comic = MockComic::make_comic($MockComic::JSON =>
        "&quot;contrib&quot;: [ &quot;&quot;]");
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_en_whitespace_quotes : Tests {
    my $comic = MockComic::make_comic($MockComic::JSON =>
        "&quot;contrib&quot;: [ &quot;   &quot;  ,  \t  &quot; &quot;]");
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_en_one : Tests {
    my $comic = MockComic::make_comic($MockComic::CONTRIBUTORS => ['Mark Dilger']);
    like(write_templ_en($comic), qr{With\s+help\s+from\s+Mark\s+Dilger}xim);
}


sub contributor_credit_en_two : Tests {
    my $comic = MockComic::make_comic($MockComic::CONTRIBUTORS =>
        ['Mark Dilger', 'Mike Karr']);
    like(write_templ_en($comic),
        qr{With\s+help\s+from\s+Mark\s+Dilger\s+and\s+Mike\s+Karr}xim);
}


sub contributor_credit_en_many : Tests {
    my $comic = MockComic::make_comic($MockComic::CONTRIBUTORS =>
        ['Mark Dilger', 'Mike Karr', 'My Self']);
    like(write_templ_en($comic),
        qr{With\s+help\s+from\s+Mark\s+Dilger,\s+Mike\s+Karr,\s+and\s+My\s+Self}xim);
}


sub contributor_credit_de_none : Test {
    my $comic = MockComic::make_comic($MockComic::CONTRIBUTORS => []);
    like(write_templ_de($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_de_empty : Tests {
    my $comic = MockComic::make_comic($MockComic::JSON =>
        "&quot;contrib&quot;: []");
    like(write_templ_en($comic), qr{\A\s*\z}xim);
}


sub contributor_credit_de_one : Test {
    my $comic = MockComic::make_comic($MockComic::CONTRIBUTORS => ['Mark Dilger']);
    like(write_templ_de($comic), qr{Mit\s+Ideen\s+von\s+Mark\s+Dilger}xim);
}


sub contributor_credit_de_two : Test {
    my $comic = MockComic::make_comic($MockComic::CONTRIBUTORS =>
        ['Mark Dilger', 'Mike Karr']);
    like(write_templ_de($comic),
        qr{Mit\s+Ideen\s+von\s+Mark\s+Dilger\s+und\s+Mike\s+Karr}xim);
}


sub contributor_credit_de_many : Test {
    my $comic = MockComic::make_comic($MockComic::CONTRIBUTORS =>
        ['Mark Dilger', 'Mike Karr', 'My Self']);
    like(write_templ_de($comic),
        qr{Mit\s+Ideen\s+von\s+Mark\s+Dilger,\s+Mike\s+Karr\s+und\s+My\s+Self}xim);
}
