#!perl
use strict;
use warnings;
use English qw(-no_match_vars);
use Test::More;


if (not $ENV{TEST_AUTHOR}) {
    my $msg = 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan(skip_all => $msg);
}

eval "use Test::Pod::LinkCheck";
if ($@) {
    plan(skip_all => 'Test::Pod::LinkCheck required for testing POD');
}
Test::Pod::LinkCheck->new->all_pod_ok;
