use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Comics;


__PACKAGE__->runtests() unless caller;


sub rejects_empty_prefixes : Tests {
    eval {
        Comics::check_settings(
            'LayerNames' => {
                'TranscriptOnlyPrefix' => '',
            },
        );
    };
    like($@, qr{TranscriptOnlyPrefix}, 'should mention bad setting');
    like($@, qr{empty}i, 'should say what is wrong');

    eval {
        Comics::check_settings(
            'LayerNames' => {
                'NoTranscriptPrefix' => '',
            },
        );
    };
    like($@, qr{NoTranscriptPrefix}, 'should mention bad setting');
    like($@, qr{empty}i, 'should say what is wrong');
}


sub check_settings_no_problems : Tests {
    my %config = (
        'LayerNames' => {
            'TranscriptOnlyPrefix' => 'Meta',
            'NoTranscriptPrefix' => 'Background',
        },
    );

    eval {
        Comics::check_settings(%config);
    };
    is($@, '');
}


sub check_settings_only_transcript_only : Tests {
    my %config = (
        'LayerNames' => {
            'TranscriptOnlyPrefix' => 'Meta',
        },
    );

    eval {
        Comics::check_settings(%config);
    };
    is($@, '');
}


sub check_settings_only_no_transcript : Tests {
    my %config = (
        'LayerNames' => {
            'NoTranscriptPrefix' => 'Background',
        },
    );

    eval {
        Comics::check_settings(%config);
    };
    is($@, '');
}


sub rejects_overlapping_prefixes_for_no_transcript_and_only_transcript : Tests {
    my %config = (
        'LayerNames' => {
            'TranscriptOnlyPrefix' => 'BackgroundText',
            'NoTranscriptPrefix' => 'Background',
        },
    );

    eval {
        Comics::check_settings(%config);
    };
    like($@, qr{TranscriptOnlyPrefix}, 'should mention TranscriptOnlyPrefix');
    like($@, qr{NoTranscriptPrefix}, 'should mention NoTranscriptPrefix');
    like($@, qr{overlap}i, 'should say what is wrong');
}
