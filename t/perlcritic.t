#!perl

if (!require Test::Perl::Critic) {
    Test::More::plan(
        skip_all => "Test::Perl::Critic required for testing PBP compliance"
    );
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
