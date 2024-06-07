package BadCheck;

use strict;
use warnings;
use Comic::Check::Check;
use base('Comic::Check::Check');


sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new();
    return $self;
}

1;
