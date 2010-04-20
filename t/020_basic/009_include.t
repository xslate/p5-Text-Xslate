#!perl -w
# NOTE: the optimizer could break goto addresses

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(cache => 0);

for(0 .. 10) { # to test including depth
    note $_;
    for(1 .. 100){
        is $tx->render('include.tx', { lang => "Xslate" }),
            "include:\n" . "Hello, Xslate world!\n";

        is $tx->render('include2.tx', { file => "hello.tx", lang => "Xslate" }),
            "include2:\n" . "Hello, Xslate world!\n";

        is $tx->render('include2.tx', { file => "include.tx", lang => "Xslate" }),
            "include2:\n" . "include:\n" . "Hello, Xslate world!\n";
    }

    eval {
        $tx->render('include2.tx', { file => "include2.tx", lang => "Xslate" });
    };
    like $@, qr/^Xslate/xms,      "recursion";
    like $@, qr/too \s+ deep/xms, "recursion";
}

done_testing;
