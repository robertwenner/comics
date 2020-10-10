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


sub no_main_config : Tests {
    my @asked_for;
    no warnings qw/redefine/;
    local *Comic::_exists = sub {
        push @asked_for, @_;
        return 0;
    };
    use warnings;

    my $comic = MockComic::make_comic();

    isnt($Comic::settings, undef, 'should have initialized settings');
    is_deeply($Comic::settings->get(), {}, 'settings shoud be empty');
    is_deeply(@asked_for, $Comic::MAIN_CONFIG_FILE, 'should have looked for config file');
}


sub laods_main_config : Tests {
    no warnings qw/redefine/;
    local *Comic::_exists = sub {
        return 1;
    };
    use warnings;
    MockComic::fake_file($Comic::MAIN_CONFIG_FILE, '{"foo": "bar"}');

    my $comic = MockComic::make_comic();

    is_deeply({"foo" => "bar"}, $Comic::settings->get(), 'should have loaded settings');
}
