package DummyCheck;

use strict;
use warnings;
use Comic::Check::Check;
use base('Comic::Check::Check');

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new();
    $self->{warning} = $args[0];
    $self->{calls} = {};
    push @{$self->{args}}, @args;
    return $self;
}

sub notify {
    my ($self) = @_;
    ${$self->{calls}}{"notify"}++;
}

sub check {
    my ($self, $comic) = @_;
    ${$self->{calls}}{"check"}++;
    $comic->warning($self->{warning}) if ($self->{warning});
}

sub final_check {
    my ($self) = @_;
    ${$self->{calls}}{"final_check"}++;
}

1;
