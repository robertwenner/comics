use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Out::HtmlComicPage;

__PACKAGE__->runtests() unless caller;


my $hcp;


sub set_up : Test(setup) {
    MockComic::set_up();
    $hcp = make_generator();
}


sub make_generator {
    my %templates = @_;
    my %options = (
        'outdir' => 'generated/web/',
        'Templates' => {
            'English' => 'en-comic.templ',
        },
    );
    foreach my $key (keys %templates) {
        $options{'Comic::Out::HtmlComicPage'}{'Templates'}{$key} = $templates{$key};
    }
    return Comic::Out::HtmlComicPage->new(%options);
}


sub url_encoded_values : Tests {
    MockComic::fake_file('comic.templ', <<'XML');
URL: [% comic.urlUrlEncoded.English %]
Title: [% comic.titleUrlEncoded.English %]
XML
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { $MockComic::ENGLISH => 'Drinking Beer' },
        $MockComic::DESCRIPTION => { $MockComic::ENGLISH => 'Paul and Max drink beer' },
    );
    my $exported = $hcp->_do_export_html($comic, 'English', 'comic.templ');
    like($exported, qr{URL: https%3A%2F%2Fbeercomics.com%2Fcomics%2Fdrinking-beer.html}m, 'URL');
    like($exported, qr{Title: Drinking%20Beer}m, 'title');
}


sub unhtml : Tests {
    is(Comic::_unhtml('&lt;&quot;&amp;&quot;&gt;'), '<"&">');
    is(Comic::_unhtml("isn't it?"), "isn't it?");
}


sub html_special_characters : Tests {
    MockComic::fake_file('en-comic.templ', '[% FILTER html %][% comic.meta_data.title.$Language %][% END %]');
    my $comic = MockComic::make_comic(
        $MockComic::TITLE => { 'English' => "&lt;Ale &amp; Lager&gt;" },
    );
    is($hcp->_do_export_html($comic, 'English', 'en-comic.templ'),
        '&lt;Ale &amp; Lager&gt;');
    $hcp->_export_language_html($comic, 'English', 'en-comic.templ');
    MockComic::assert_wrote_file('generated/web/english/comics/ale-lager.html',
        '&lt;Ale &amp; Lager&gt;');
}


sub provides_defaults_if_not_given : Tests {
    MockComic::fake_file("en-comic.templ", '[% FILTER html %][% comic.meta_data.title.$Language %][% END %]');
    foreach my $what (qw(tags who)) {
        my $comic = MockComic::make_comic();
        $hcp->_do_export_html($comic, 'English', 'en-comic.templ');
        is_deeply($comic->{meta_data}{who}{English}, [], "$what not added");
    }
}
