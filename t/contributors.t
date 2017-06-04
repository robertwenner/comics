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
[% DEFAULT comic.meta_data.contrib = 0 %]
[% IF comic.meta_data.contrib && comic.meta_data.contrib.size %]
    <p style="contributors">With help from
        [% FOREACH c IN comic.meta_data.contrib %]
            [% c != comic.meta_data.contrib.first && c == comic.meta_data.contrib.last ? ' and ' : '' %]
            [% c %][% comic.meta_data.contrib.defined(2) ? ', ' : '' %]
        [% END %]
    </p>
[% END %]
TEMPL
    return fake_template($template, @_);
}


sub write_templ_de {
    my $template = <<'TEMPL';
[% DEFAULT comic.meta_data.contrib = 0 %]
[% IF comic.meta_data.contrib && comic.meta_data.contrib.size %]
    <p style="contributors">Mit Ideen von
[% FOREACH c IN comic.meta_data.contrib %][% c != comic.meta_data.contrib.first && c == comic.meta_data.contrib.last ? ' und ' : '' %][% c != comic.meta_data.contrib.first && c != comic.meta_data.contrib.last ? ', ' : '' %][% c %][% END %]
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


sub translator_ok : Tests {
    my $template = <<'TEMPL';
[% IF translator %]
    <p style="contributors">Übersetzt von [% translator %].</p>
[% END %]
TEMPL
    my $comic = MockComic::make_comic($MockComic::TRANSLATOR => {
        $MockComic::ENGLISH => 'mir',
    });
    like(fake_template($template, $comic), qr{Übersetzt von mir}im);
}


sub translator_none : Tests {
    my $template = <<'TEMPL';
[% IF translator %]
    <p style="contributors">Übersetzt von [% translator %].</p>
[% END %]
TEMPL
    my $comic = MockComic::make_comic($MockComic::TRANSLATOR => {
        $MockComic::DEUTSCH => 'mir',
    });
    like(fake_template($template, $comic), qr{^\s*$}m);
}
