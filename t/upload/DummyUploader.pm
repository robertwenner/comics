package DummyUploader;

use strict;
use warnings;
use Test::More;

use Comic::Upload::Uploader;
use base('Comic::Upload::Uploader');


sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new();

    @{$self->{ctor_params}} = [@args];
    $self->{called} = 0;
    $self->{posted} = [];

    return $self;
}


sub assert_constructed {
    my ($self, @expected_ctor_params) = @_;
    is_deeply(@{$self->{ctor_params}}, [@expected_ctor_params], 'wrong constructor params');
}


sub upload {
    my ($self, @args) = @_;
    $self->{called}++;
    push @{$self->{uploaded}}, @args;
    return 'DummyUploader uploaded';
}


sub assert_uploaded {
    my ($self, @expected) = @_;
    is_deeply($self->{uploaded}, \@expected, 'wrong upload');
}


1;
