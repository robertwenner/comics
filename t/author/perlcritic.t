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
        # I still find '' or "" more readable than q{}.
        'ValuesAndExpressions::ProhibitEmptyQuotes',
        # These are valid languages features, IMHO. When used correctly, of course.
        'ControlStructures::ProhibitPostfixControls',
        'ControlStructures::ProhibitUnlessBlocks',
        # Documentation should be close to the code it documents so that it's
        # easy to keep in sync.
        'Documentation::RequirePodAtEnd',
        # =cut and __END__ after POD seems like premature wishful optimization.
        'Documentation::RequireEndBeforeLastPod',
        'Documentation::RequireFinalCut',
        # Too finicky: picks up unrelated values that happen to be the same,
        # but just because font size is 10 point and frame difference is 10
        # pixels does not mean they should use the same constant.
        'TooMuchCode::ProhibitDuplicateLiteral',
        # Code base does not use exceptions but does use base.
        'Perl::Critic::Policy::ErrorHandling::RequireUseOfExceptions',
        'Tics::ProhibitUseBase',
        # Comic is a value object.
        'ValuesAndExpressions::ProhibitAccessOfPrivateData',
        # I wonder what time machine these policies came from:
        'CodeLayout::RequireASCII',
        'TooMuchCode::ProhibitUnnecessaryUTF8Pragma',
        # Nobody on the team (me) uses Emacs.
        'Editor::RequireEmacsFileVariables',
        # Too many false positives; triggers on string comparison eq operator,
        # where any typo is an error anyway. Also, I've never been bitten by
        # a == vs = typo.
        'ValuesAndExpressions::RequireConstantOnLeftSideOfEquality',
        # Too finicky; a long message does not get shorter by splitting it over
        # multiple lines.
        'ValuesAndExpressions::RestrictLongStrings',
        # We're not on punch cards anymore...
        'Tics::ProhibitLongLines',
        # Tidy style is ugly, way too much white space, e.g., aligning assignment
        # operators on consecutive lines of assignments, or after an opening and
        # before a closing paren.
        'CodeLayout::RequireTidyCode',
        # Look at those in detail:
        'Modules::RequirePerlVersion',
        'Compatibility::PerlMinimumVersionAndWhy',
        'Compatibility::PodMinimumVersion',
        # Look into this on a rainy weekend.
        'RegularExpressions::RequireExtendedFormatting',
        'RegularExpressions::RequireDotMatchAnything',
        'RegularExpressions::RequireLineBoundaryMatching',
    ],
);
Test::Perl::Critic::all_critic_ok();
