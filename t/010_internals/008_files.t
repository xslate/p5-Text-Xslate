#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use FindBin qw($Bin);
use t::lib::Util;
use File::Copy qw(copy move);
use File::Path qw(rmtree);

use Fatal qw(utime);

my @files  = (path."/hello.tx",  path."/for.tx");
my @caches;

rmtree cache_dir;
my $x = path."/hello.tx";
END{
    move "$x.save" => $x if $x && -f "$x.save";
    rmtree cache_dir;
}

{
    my $tx = Text::Xslate->new(
        path      => [path],
        cache_dir => cache_dir,
    );

    push @caches, $tx->find_file($_)->{cachepath}
        for qw(hello.tx for.tx);
}

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

unlink @caches;

my $tx = Text::Xslate->new(path => [path], cache_dir => cache_dir);

is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "file";

# change the content
move  $x      => "$x.save";
copy "$x.mod" =>  $x;

utime $^T+10, $^T+10, $x;

is $tx->render('hello.tx', { lang => 'Perl' }),
    "Hi, Perl.\n", "auto reload $_" for 1 .. 2;

move "$x.save" => $x or diag "cannot move $x.save to $x: $!";

unlink @caches;

note 'cache => 2 (release mode)';

$tx = Text::Xslate->new(cache => 2, path => [path], cache_dir => cache_dir);

utime $^T, $^T, $x;

is $tx->render('hello.tx', { lang => 'Xslate' }),
    "Hello, Xslate world!\n", "first" for 1 .. 2;

# change the content
move  $x      => "$x.save";
copy "$x.mod" =>  $x;

utime $^T+10, $^T+10, $x;

is $tx->render('hello.tx', { lang => 'Xslate' }),
    "Hello, Xslate world!\n", "second (modified, but not reloaded)" for 1 .. 2;



done_testing;
