#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use FindBin qw($Bin);
use t::lib::Util;
use File::Copy qw(copy move);

my @caches = (path."/hello.txc", path."/for.txc");

unlink @caches; # ensure not to exist

for(1 .. 10) {
    my $tx = Text::Xslate->new(
        file => [qw(hello.tx for.tx)],
        path => [path],
    );

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n", "file (preload)";

    is $tx->render('for.tx', { books => [ { title => "Foo" }, { title => "Bar" } ]}),
        "[Foo]\n[Bar]\n", "file (preload)";

    ok -e $_, "$_ exists" for @caches;

    if(($_ % 3) == 0) {
        my $t = time + $_;
        utime $t, $t, @caches;
    }
}

for(1 .. 10) {
    my $tx = Text::Xslate->new(path => [path]);

    is $tx->render('hello.tx', { lang => 'Xslate' }),
        "Hello, Xslate world!\n", "file (on demand)";

    is $tx->render('for.tx', { books => [ { title => "Foo" }, { title => "Bar" } ]}),
        "[Foo]\n[Bar]\n", "file (on demand)";

    if(($_ % 3) == 0) {
        my $t = time + $_;
        utime $t, $t, @caches;
    }
}

unlink @caches;

my $tx = Text::Xslate->new(path => [path]);

is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "file";

my $x = path."/hello.tx";

# change the content
move  $x      => "$x.save";
copy "$x.mod" =>  $x;

utime $^T+10, $^T+10, $x;

is $tx->render('hello.tx', { lang => 'Perl' }),
    "Hi, Perl.\n", "auto reload" for 1 .. 2;

move "$x.save" => $x or diag "cannot move $x.save to $x: $!";

unlink @caches;

note 'cache => 2 (release mode)';

$tx = Text::Xslate->new(cache => 2, path => [path]);

utime $^T, $^T, $x;

is $tx->render('hello.tx', { lang => 'Xslate' }),
    "Hello, Xslate world!\n", "first" for 1 .. 2;

# change the content
move  $x      => "$x.save";
copy "$x.mod" =>  $x;

utime $^T+10, $^T+10, $x;

is $tx->render('hello.tx', { lang => 'Xslate' }),
    "Hello, Xslate world!\n", "second (modified, but not reloaded)" for 1 .. 2;

move "$x.save" => $x;

unlink(@caches) or diag "Cannot unlink: $!";

done_testing;
