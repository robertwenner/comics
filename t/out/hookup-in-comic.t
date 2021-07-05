use strict;
use warnings;

use base 'Test::Class';
use Test::More;
use lib 't/out';
use DummyGenerator;

use lib 't';
use MockComic;
use Comics;
use Comic::Out::Generator;


__PACKAGE__->runtests() unless caller;


sub set_up : Test(setup) {
    MockComic::set_up();
}


sub generator_base_class_does_nothing : Tests {
    my $gen = Comic::Out::Generator->new();
    $gen->generate();
    $gen->generate_all();
    ok(1);
}


sub runs_output_generators_in_stages : Tests {
    my $comics = Comics->new();
    my $gen = DummyGenerator->new();
    @{$comics->{generators}} = ($gen, $gen);
    @{$comics->{comics}} = (MockComic::make_comic());

    $comics->_generate();

    is_deeply($gen->{called}, ['generate', 'generate', 'generate_all', 'generate_all']);
}
