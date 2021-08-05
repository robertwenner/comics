use strict;
use warnings;
use Test::More;

plan(skip_all => 'Not on CPAN yet');

__END__
eval 'use Test::GreaterVersion';
plan skip_all => 'Test::GreaterVersion required for this test' if $@;
has_greater_version_than_cpan('Comic');
ok(1);  # to prevent a "no tests found" error when the module isn't on CPAN yet
done_testing();
