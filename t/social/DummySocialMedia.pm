package DummySocialMedia;

use strict;
use warnings;
use Test::More;

use Comic::Social::Social;
use base('Comic::Social::Social');


sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new();

    @{$self->{ctor_params}} = [@args];
    $self->{posted} = [];

    return $self;
}


sub assert_constructed {
    my ($self, @expected_ctor_params) = @_;
    is_deeply(@{$self->{ctor_params}}, [@expected_ctor_params], 'wrong constructor params');
}


sub post {
    my ($self, @comics) = @_;
    push @{$self->{posted}}, @comics;
    return "posted to dummy\n";
}


sub assert_posted {
    my ($self, @expected_comics) = @_;
    my %expected = map { $_ => 1 } @expected_comics;
    my %is = map { $_ => 1 } @{$self->{posted}};
    # Put the comics in a hash for comparison, so that order does not matter.
    is_deeply(\%is, \%expected, 'posted wrong comics');
}


1;
