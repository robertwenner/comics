package DummyGenerator;

use strict;
use warnings;
use Comic::Out::Generator;
use base('Comic::Out::Generator');

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new();
    @{$self->{called}} = ();
    return $self;
}

sub generate {
    my ($self) = @_;
    push @{$self->{called}}, "generate";
}

sub generate_all {
    my ($self) = @_;
    push @{$self->{called}}, "generate_all";
}

1;
