package DummyGenerator;

use strict;
use warnings;
use Comic::Out::Generator;
use base('Comic::Out::Generator');

sub new {
    my ($class, %settings) = @_;
    my $self = $class->SUPER::new(%settings);
    @{$self->{called}} = ();
    $self->{up_to_date} = 0;
    return $self;
}

sub up_to_date {
    my ($self, $file) = @_;
    return $self->{up_to_date};
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
