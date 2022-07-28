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
        'template' => {
            'English' => 'en-comic.templ',
        },
    );
    foreach my $key (keys %templates) {
        $options{'Comic::Out::HtmlComicPage'}{'template'}{$key} = $templates{$key};
    }
    return Comic::Out::HtmlComicPage->new(%options);
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
    $hcp->generate($comic);
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
        $hcp->generate($comic);
        $hcp->_do_export_html($comic, 'English', 'en-comic.templ');
        is_deeply($comic->{meta_data}{who}{English}, [], "$what not added");
    }
}
