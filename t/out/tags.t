use strict;
use warnings;
use utf8;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;

use Comic::Out::Tags;

__PACKAGE__->runtests() unless caller;

my $max_beer_brewing;
my $max_paul_beer_brewing;


sub set_up : Test(setup) {
    MockComic::set_up();

    $max_beer_brewing = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Max Bier brauen',
            $MockComic::ENGLISH => 'Max beer brewing',
        },
        $MockComic::TAGS => {
            $MockComic::DEUTSCH => ['Bier', 'Brauen'],
            $MockComic::ENGLISH => ['beer', 'brewing'],
        },
        $MockComic::WHO => {
            $MockComic::DEUTSCH => ['Max'],
            $MockComic::ENGLISH => ['Max'],
        },
    );
    $max_beer_brewing->{href}{'Deutsch'} = 'comics/max-bier-brauen.html';
    $max_beer_brewing->{href}{'English'} = 'comics/max-beer-brewing.html';

    $max_paul_beer_brewing = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::DEUTSCH => 'Max Paul Bier brauen',
            $MockComic::ENGLISH => 'Max Paul beer brewing',
        },
        $MockComic::TAGS => {
            $MockComic::DEUTSCH => ['Bier', 'Brauen'],
            $MockComic::ENGLISH => ['beer', 'brewing'],
        },
        $MockComic::WHO => {
            $MockComic::DEUTSCH => ['Max', 'Paul'],
            $MockComic::ENGLISH => ['Max', 'Paul'],
        },
    );
    $max_paul_beer_brewing->{href}{'Deutsch'} = 'comics/max-paul-bier-brauen.html';
    $max_paul_beer_brewing->{href}{'English'} = 'comics/max-paul-beer-brewing.html';
}


sub default_configuration : Tests {
    my $tags = Comic::Out::Tags->new();
    is_deeply(${$tags->{settings}}{collect}, ['tags']);
}


sub configure_collect_array : Tests {
    my $tags = Comic::Out::Tags->new(collect => ['who', 'tags']);
    is_deeply(${$tags->{settings}}{collect}, ['who', 'tags']);
}


sub configure_collect_scalar : Tests {
    my $tags = Comic::Out::Tags->new(collect => 'who');
    is_deeply(${$tags->{settings}}{collect}, ['who']);
}


sub configure_collect_rejects_hash : Tests {
    eval {
        Comic::Out::Tags->new(collect => { 'tags' => 1 });
    };
    like($@, qr{\barray\b}i, 'should say what is wrong');
}


sub adds_tags_to_comic : Tests {
    my $tags = Comic::Out::Tags->new(collect => 'tags');
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->generate_all($max_beer_brewing, $max_paul_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {
        'Bier' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
        'Brauen' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
    });
    is_deeply($max_beer_brewing->{tags}{'English'}, {
        'beer' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
        'brewing' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
    });
}


sub adds_tags_and_who_to_comic : Tests {
    my $tags = Comic::Out::Tags->new(collect => ['tags', 'who']);
    $tags->generate($max_beer_brewing);
    $tags->generate($max_paul_beer_brewing);
    $tags->generate_all($max_beer_brewing, $max_paul_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {
        'Bier' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
        'Brauen' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
        'Max' => {
            'Max Paul Bier brauen' => 'comics/max-paul-bier-brauen.html'
        },
    });
    is_deeply($max_beer_brewing->{tags}{'English'}, {
        'beer' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
        'brewing' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
        'Max' => {
            'Max Paul beer brewing' => 'comics/max-paul-beer-brewing.html'
        },
    });
}


sub ignores_comic_without_tags : Tests {
    my $tags = Comic::Out::Tags->new(collect => ['something']);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'Deutsch'}, {});
    is_deeply($max_beer_brewing->{tags}{'English'}, {});
}


sub ignores_comic_with_empty_tags : Tests {
    my $no_tags = MockComic::make_comic(
        $MockComic::JSON => '"tags": {},',
    );

    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($no_tags);
    $tags->generate_all($no_tags);

    is_deeply($no_tags->{tags}{'English'}, {});
}


sub nice_error_message_if_tags_meta_data_is_not_an_hash : Tests {
    my $oops = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Oops',
        },
        $MockComic::JSON => '"tags": "no language hash",',
    );

    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    eval {
        $tags->generate($oops);
    };
    like($@, qr{\bhash\b}i, 'should say what is wrong');
    like($@, qr{\blanguages\b}i, 'should say what is wrong');
    like($@, qr{\btags\b}i, 'should name the bad metadata');
}


sub nice_error_message_if_tags_meta_data_per_language_is_not_an_array : Tests {
    my $oops = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Oops',
        },
        $MockComic::JSON => '"tags": {"English": "beer"},',
    );

    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    eval {
        $tags->generate($oops);
    };
    like($@, qr{\barray\b}i, 'should say what is wrong');
    like($@, qr{\btags\b}i, 'should name the bad metadata');
    like($@, qr{\bEnglish\b}i, 'should include the language');
}


sub does_not_refer_to_comics_without_title : Tests {
    my $untitled = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => '',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
    );
    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($untitled);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($untitled, $max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is($untitled->{tags}{'English'}, undef);
}


sub does_not_refer_to_comic_that_is_not_yet_published : Tests {
    my $unpublished = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Publish me',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
        $MockComic::PUBLISHED_WHEN => '',
        $MockComic::PUBLISHED_WHERE => 'web',
    );
    my $tags = Comic::Out::Tags->new(collect => ['tags']);

    $tags->generate($unpublished);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($unpublished, $max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is($unpublished->{tags}{'English'}, undef);
}


sub does_not_refer_to_comic_that_is_not_published_on_the_web : Tests {
    my $elsewhere = MockComic::make_comic(
        $MockComic::TITLE => {
            $MockComic::ENGLISH => 'Published elsewhere',
        },
        $MockComic::TAGS => {
            $MockComic::ENGLISH => ['beer'],
        },
        $MockComic::PUBLISHED_WHEN => '2020-01-01',
        $MockComic::PUBLISHED_WHERE => 'elsewhere',
    );
    my $tags = Comic::Out::Tags->new(collect => ['tags']);
    $tags->generate($elsewhere);
    $tags->generate($max_beer_brewing);
    $tags->generate_all($elsewhere, $max_beer_brewing);

    is_deeply($max_beer_brewing->{tags}{'English'}, {});
    is($elsewhere->{tags}{'English'}, undef);
}
