use strict;
use warnings;

use utf8;
use base 'Test::Class';
use Test::More;
use Test::MockModule;

use Comic::Social::Mastodon;


__PACKAGE__->runtests() unless caller;


sub only_title : Tests {
    is(Comic::Social::Mastodon::_build_message('title'), 'title');
}


sub only_description : Tests {
    is(Comic::Social::Mastodon::_build_message(undef, 'description'), 'description');
}


sub only_tags : Tests {
    is(
        Comic::Social::Mastodon::_build_message('', '', '', '#tag1', '#tag2'),
        '#tag1 #tag2');
}


sub only_url : Tests {
    is(
        Comic::Social::Mastodon::_build_message('', '', 'https://example.org'),
        'https://example.org');
}


sub title_description_tags : Tests {
    is(
        Comic::Social::Mastodon::_build_message('title', 'description', undef, '#tag1', '#tag2', '#tag3'),
        "title\ndescription\n#tag1 #tag2 #tag3");
}


sub with_all_fields : Tests {
    is(
        Comic::Social::Mastodon::_build_message('title', 'description', 'https://example.org', '#tag1'),
        "title\ndescription\n#tag1\nhttps://example.org");
}


sub shortens_too_long_description : Tests {
    my $shortened = Comic::Social::Mastodon::_build_message('title', '.' x 1000);
    is(length($shortened), 500);
    is($shortened, "title\n" . ('.' x 494));
}


sub shortens_description_if_everything_is_too_long : Tests {
    my $shortened = Comic::Social::Mastodon::_build_message('title', '.' x 1000, 'https://comics.com', '#tag1', '#tag2');
    is(length($shortened), 500);
    # title = 5, nl, tags = 2 * 5 + space + nl, nl + url = 18 => 37
    is($shortened, "title\n" . ('.' x (500 - 37)) . "\n#tag1 #tag2\nhttps://comics.com");
}


sub shortens_title_already_too_long : Tests {
    my $shortened = Comic::Social::Mastodon::_build_message('x' x 1000, 'y' x 200);
    is(length($shortened), 500);
    like($shortened, qr{^x{500}$});
}


sub shortens_title_under_limit_with_tags_over : Tests {
    my $shortened = Comic::Social::Mastodon::_build_message('x' x 490, 'y' x 200, '', '#tag1', '#tag2', '#tag3');
    is(length($shortened), 500);
    like($shortened, qr{^x+\n#tag1 #tag2 #tag3$});
}
