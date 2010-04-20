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

    is $tx->render('hello.tx', { lang => 'Xslate' }), "Hello, Xslate world!\n", "file";

    is $tx->render('for.tx', { books => [ { title => "Foo" }, { title => "Bar" } ]}),
        "[Foo]\n[Bar]\n", "file";

    ok -e $_, "$_ exists" for @caches;

    if(($_ % 3) == 0) {
        my $t = time + $_;
        utime $t, $t, @caches;
    }
}

unlink @caches;

done_testing;
