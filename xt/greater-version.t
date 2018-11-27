use strict;
use warnings;
use Test::More;

eval 'use Test::GreaterVersion';
plan skip_all => 'Test::GreaterVersion required for this test' if $@;
has_greater_version_than_cpan('Comic');
ok(1);  # to prevent a "no tests found" error when the module isn't on CPAN yet
done_testing();