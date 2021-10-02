use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use lib 't';
use MockComic;
use Comic::Out::FileCopy;


__PACKAGE__->runtests() unless caller;


my @ran;
my @cp_args;


sub setup : Test(setup) {
    MockComic::set_up();
    @ran = ();
    @cp_args = ();
}


    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_cp = sub {
        push @cp_args, (@_);
    };
    use warnings;
sub make_copy {
    my ($from_all, $from_language) = @_;

    return Comic::Out::FileCopy->new(
        'outdir' => 'generated/web',
        'from-all' => $from_all,
        'from-language' => $from_language,
    );
}


sub consructor_complains_about_missing_configuration : Tests {
    eval {
        Comic::Out::FileCopy->new();
    };
    like($@, qr{\bComic::Out::FileCopy\b}, 'should mention module');

    eval {
        Comic::Out::FileCopy->new('outdir' => 'generated/web/');
    };
    like($@, qr{from-all}, 'should mention missing setting');
    like($@, qr{from-language}, 'should mention missing setting');

    eval {
        Comic::Out::FileCopy->new(
            'outdir' => 'generated/web/',
            'from-all' => {},
        );
    };
    like($@, qr{from-all}, 'should mention bad setting');
    like($@, qr{\bscalar\b}, 'should mention it wants a scalar');
    like($@, qr{\barray\b}, 'should mention it wants an array');
}


sub creates_output_directories : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_cp = sub {
        push @cp_args, (@_);
    };
    use warnings;

    # Comic's constructor creates its meta directory, so mock mkdir only afterwards.
    # (Before this mock it's mocked by MockComic.)
    my $comic = MockComic::make_comic();

    my @mkdirs;
    no warnings qw/redefine/;
    local *File::Path::make_path = sub {
        push @mkdirs, @_;
    };
    use warnings;

    my $copy = make_copy('web/all', 'web');
    $copy->generate_all($comic);

    is_deeply(['generated/web/deutsch', 'generated/web/english'], \@mkdirs, 'created wrong directories');
}


sub runs_cp_language_independent_scalar : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_cp = sub {
        push @cp_args, (@_);
    };
    use warnings;

    my $copy = make_copy('web/all');
    $copy->generate_all(MockComic::make_comic());

    my @expected = [
        qw(web/all/* generated/web/deutsch),
        qw(web/all/* generated/web/english),
    ];
    is_deeply(\@cp_args, @expected);
}


sub runs_cp_language_independent_array : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_cp = sub {
        push @cp_args, (@_);
    };
    use warnings;

    my $copy = make_copy(['web/all', 'web/some', 'web/misc']);
    $copy->generate_all(MockComic::make_comic());

    my @expected = [
        qw(web/all/* generated/web/deutsch),
        qw(web/some/* generated/web/deutsch),
        qw(web/misc/* generated/web/deutsch),
        qw(web/all/* generated/web/english),
        qw(web/some/* generated/web/english),
        qw(web/misc/* generated/web/english),
    ];
    is_deeply(\@cp_args, @expected);
}


sub runs_cp_per_language_scalar : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_cp = sub {
        push @cp_args, (@_);
    };
    use warnings;

    my $copy = make_copy(undef, 'web');
    $copy->generate_all(MockComic::make_comic());

    my @expected = [
        qw(web/deutsch/* generated/web/deutsch),
        qw(web/english/* generated/web/english),
    ];
    is_deeply(\@cp_args, @expected);
}


sub runs_cp_per_language_array : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_cp = sub {
        push @cp_args, (@_);
    };
    use warnings;

    my $copy = make_copy(undef, ['web/langs', 'web/more']);
    $copy->generate_all(MockComic::make_comic());

    my @expected = [
        qw(web/langs/deutsch/* generated/web/deutsch),
        qw(web/more/deutsch/* generated/web/deutsch),
        qw(web/langs/english/* generated/web/english),
        qw(web/more/english/* generated/web/english),
    ];
    is_deeply(\@cp_args, @expected);
}


sub cp_arguments : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_system = sub {
        push @ran, (@_);
        return 0;
    };
    use warnings;

    Comic::Out::FileCopy::_cp("from1", "from2", "from3", "to");

    my @expected = ('cp --archive --recursive --update from1 from2 from3 to');
    is_deeply(\@ran, \@expected);
}


sub reports_mkdir_errors : Tests {
    my $comic =MockComic::make_comic();

    no warnings qw/redefine/;
    local *File::Path::make_path = sub {
        die "something went wrong";
    };
    use warnings;

    my $copy = make_copy('web/all', 'web');
    eval {
        $copy->generate_all($comic);
    };
    like($@, qr{\bsomething went wrong\b}, 'should have error message');
    like($@, qr{\bComic::Out::FileCopy\b}, 'should have module name');
}


sub reports_cp_errors : Tests {
    no warnings qw/redefine/;
    local *Comic::Out::FileCopy::_system = sub {
        return 123;
    };
    use warnings;

    my $copy = make_copy('web/all', 'web');
    eval {
        $copy->generate_all(MockComic::make_comic());
    };
    like($@, qr{\bcannot copy\b}i, 'should have a message');
    like($@, qr{\b123\b}i, 'should include exit code');
    like($@, qr{\bComic::Out::FileCopy\b}i, 'should include module name');
}
