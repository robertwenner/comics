#!perl
use strict;
use warnings;
use Test::More;


if (not $ENV{TEST_AUTHOR}) {
    my $msg = 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan(skip_all => $msg);
}

eval "use Test::Pod::No404s";
if ($@) {
    plan skip_all => 'Test::Pod::No404s required for testing POD';
}
all_pod_files_ok();
