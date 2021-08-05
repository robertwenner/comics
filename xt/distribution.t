use Test::More;

plan(skip_all => 'Not on CPAN yet');

__END__

eval 'require Test::Distribution';
plan(skip_all => 'Test::Distribution not installed') if $@;
Test::Distribution->import(not => 'description');
