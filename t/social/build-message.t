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
        Comic::Social::Mastodon::_build_message('', '', 'example.org'),
        'example.org');
}


sub title_description_tags : Tests {
    is(
        Comic::Social::Mastodon::_build_message('title', 'description', undef, '#tag1', '#tag2', '#tag3'),
        "title\ndescription\n#tag1 #tag2 #tag3");
}


sub with_all_fields : Tests {
    is(
        Comic::Social::Mastodon::_build_message('title', 'description', 'example.org', '#tag1'),
        "title\ndescription\n#tag1\nexample.org");
}


sub shortens_too_long_description : Tests {
    my $shortened = Comic::Social::Mastodon::_build_message('title', '.' x 1000);
    is(length($shortened), 500);
    is($shortened, "title\n" . ('.' x 494));
}


sub shortens_description_if_maximum_length_is_exceeded : Tests {
    my $shortened = Comic::Social::Mastodon::_build_message('title', '.' x 1000, 'comics.com', '#tag1', '#tag2');
    is(length($shortened), 500);
    # title + nl = 6, nl after description, tags = 2 * 5 + space + nl = 12, url = 10 => 29
    is($shortened, "title\n" . ('.' x (500 - 29)) . "\n#tag1 #tag2\ncomics.com");
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


sub textlen_nothing_special : Tests {
    is(Comic::Social::Mastodon::_textlen(undef), 0);
    is(Comic::Social::Mastodon::_textlen(''), 0);
    is(Comic::Social::Mastodon::_textlen('1'), 1);
    is(Comic::Social::Mastodon::_textlen('abc'), 3);
}


sub url_counts_for_23_characters : Tests {
    is(Comic::Social::Mastodon::_textlen('http://example.org'), 23);
    is(Comic::Social::Mastodon::_textlen('https://example.org'), 23);
    is(Comic::Social::Mastodon::_textlen('ftp://example.org'), length 'ftp://example.org');
    is(Comic::Social::Mastodon::_textlen('text http://example.org text'), 5 + 23 + 5);
    is(Comic::Social::Mastodon::_textlen('text http://example.org text http://example.org text'), 5 + 23 + 6 + 23 + 5);
}


sub mentions_dont_count_instance_name : Tests {
    is(Comic::Social::Mastodon::_textlen('@me'), 3);
    is(Comic::Social::Mastodon::_textlen('@me@instance'), 3);
    is(Comic::Social::Mastodon::_textlen('https://example.org@me@not-an-instance'), 23);
}


sub shortens_using_mastodon_special_rules : Tests {
    my $title = 'Black Friday'; # 5 + 1 + 6 = 12
    my $url = 'https://beercomics.com/comics/black-friday.html'; # 23
    my @tags = ('@you@instance'); # 4
    my $has_room_for = 500 - (12 + 1 + 1 + 23 + 1 + 4); # 1 for each \n in between
    my $description = 'x' x 1000;

    my $shortened = Comic::Social::Mastodon::_build_message($title, $description, $url, @tags);

    like($shortened, qr{
        ^
        Black\sFriday\n
        x{$has_room_for}\n
        \@you\@instance\n
        https://beercomics\.com/comics/black-friday\.html
        $
    }x);
}
