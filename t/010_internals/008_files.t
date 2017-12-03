#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use lib "t/lib";
use Util;
use File::Copy qw(copy move);
use File::Spec;

use Fatal qw(utime);

subtest normal => sub {
    Util::reinit();

    my $tx = Text::Xslate->new(
        path      => [path],
        cache_dir => cache_dir,
    );

    my @files = map { File::Spec->catfile(path, $_) } qw(hello.tx for.tx);
    my @caches = map { $tx->find_file($_)->{cachepath} } qw(hello.tx for.tx);

    for(1 .. 10) {
        my $tx = Text::Xslate->new(
            path      => [path],
            cache_dir => cache_dir,
        );

        is $tx->render('hello.tx', { lang => 'Xslate' }),
            "Hello, Xslate world!\n", "file (preload $_)";

        is $tx->render('for.tx', { books => [ { title => "Foo" }, { title => "Bar" } ]}),
            "[Foo]\n[Bar]\n", "file (preload $_)";

        ok -e $_, "$_ exists" for @caches;

        if(($_ % 3) == 0) {
            my $t = time + $_;
            utime $t, $t, @caches;
        }
    }

    for(1 .. 10) {
        my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);

        is $tx->render('hello.tx', { lang => 'Xslate' }),
            "Hello, Xslate world!\n", "file (on demand $_)";

        is $tx->render('for.tx', { books => [ { title => "Foo" }, { title => "Bar" } ]}),
            "[Foo]\n[Bar]\n", "file (on demand $_)";

        if(($_ % 3) == 0) {
            my $t = time() + $_*10;
            utime $t, $t, @files;
        }
    }
};

subtest 'cache => 1 (default mode)' => sub {
    Util::reinit();

    my $x = File::Spec->catfile(path, "hello.tx");
    my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);

    is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "file";

    # change the content
    copy "$x.mod", $x;

    utime $^T+10, $^T+10, $x;

    is $tx->render('hello.tx', { lang => 'Perl' }),
        "Hi, Perl.\n", "auto reload $_" for 1 .. 2;
};

subtest 'cache => 2 (release mode)' => sub {
    Util::reinit();

    my $x = File::Spec->catfile(path, "hello.tx");
    my $tx = Text::Xslate->new(cache => 2, path => [path], cache_dir => cache_dir);

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n", "first" for 1 .. 2;

    # change the content
    copy "$x.mod", $x;

    utime $^T+10, $^T+10, $x;

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n", "second (modified, but not reloaded)" for 1 .. 2;
};

done_testing;
