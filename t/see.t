use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
    MockComic::fake_file('template', <<'TEMPL');
    [% FOREACH s IN see %]
        [% s.key %] -> [% s.value %]
    [% END %]
TEMPL
}


sub no_see : Tests {
    my $comic = MockComic::make_comic();
    my $html = $comic->_do_export_html('English', 'template');
    is_deeply($comic->{warnings}, []);
    like($html, qr{^\s*$}m);
}


sub empty_see : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
            },
        },
    );
    my $html = $comic->_do_export_html('English', 'template');
    is_deeply($comic->{warnings}, []);
    like($html, qr{^\s*$}m);
}


sub dead_link : Tests {
    my $comic = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "some comic" => "oops.svg",
            },
        },
        $MockComic::IN_FILE => 'referrer.svg',
    );
    eval {
        $comic->_do_export_html('English', 'template');
    };
    like($@, qr{^referrer\.svg: English link refers to non-existent oops\.svg});
}


sub links_to_url : Tests {
    my $referenced = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'The origins',
        },
        $MockComic::IN_FILE => 'origins.svg',
    );
    my $referrer = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                "the original comic" => "origins.svg",
            }
        },
        $MockComic::IN_FILE => 'referrer.svg',
    );
    my $html = $referrer->_do_export_html('English', 'template');
    like($html, qr{the original comic -> \S+/comics/the-origins\.html}m);
}


sub html_encodes_links : Tests {
    my $referenced = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'The origins',
        },
        $MockComic::IN_FILE => 'origins.svg',
    );
    my $referrer = MockComic::make_comic(
        $MockComic::SEE => {
            $MockComic::ENGLISH => {
                'the &lt;original&gt; comic' => "origins.svg",
            }
        },
        $MockComic::IN_FILE => 'referrer.svg',
    );
    my $html = $referrer->_do_export_html('English', 'template');
    like($html, qr{the &lt;original&gt; comic -> \S+/comics/the-origins\.html}m);
}
