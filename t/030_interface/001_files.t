#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use FindBin qw($Bin);

my @caches = ("$Bin/../template/hello.txc", "$Bin/../template/for.txc");

ok !-e $_, "$_ does not exist" for @caches;

for(1 .. 10) {
    my $tx = Text::Xslate->new(
        file => [qw(hello.tx for.tx)],
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
    my $tx = Text::Xslate->new();

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

my $tx = Text::Xslate->new();

is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "file";

my $x = "$Bin/../template/hello.tx";
my $y = "$Bin/../template/hello2.tx";

my $t = time;
utime $t, $t, $x;
$t += 10;
utime $t, $t, $y;

rename $x => "${x}~";
rename $y => $x;

is $tx->render('hello.tx', { lang => 'Xslate' }), "Hi, Xslate world!\n", "auto reload";

rename $x => $y;
rename "${x}~" => $x;

is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "auto reload";

unlink(@caches) or diag "Cannot unlink: $!";

done_testing;
