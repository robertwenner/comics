#!perl
use strict;
use warnings;
use English qw(-no_match_vars);
use Test::More;


if (not $ENV{TEST_AUTHOR}) {
    my $msg = 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan(skip_all => $msg);
}

eval { require Test::Perl::Critic; };
if ($EVAL_ERROR ) {
    my $msg = 'Test::Perl::Critic required to criticise code';
    plan(skip_all => $msg);
}

Test::Perl::Critic->import(
    -severity => 1,
    -verbose => "Severity: %s: %p: %m (%e) at %f line %l\n",
    -exclude => [
        'ValuesAndExpressions::ProhibitEmptyQuotes',
        'RegularExpressions::RequireExtendedFormatting',
        'RegularExpressions::RequireDotMatchAnything',
        'RegularExpressions::RequireLineBoundaryMatching',
        'RegularExpressions::ProhibitEscapedMetacharacters',
        'ControlStructures::ProhibitPostfixControls',
        'ControlStructures::ProhibitUnlessBlocks',
        'Documentation::RequirePodAtEnd',
        'CodeLayout::RequireTidyCode',
    ],
);
Test::Perl::Critic::all_critic_ok();
