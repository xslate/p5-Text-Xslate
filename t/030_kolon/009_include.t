#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use lib "t/lib";
use Util;

my $tx = Text::Xslate->new(cache => 0, path => [path]);

for(1 .. 2) { # to test including depth
    for(1 .. 100){
        is $tx->render('include.tx', { lang => "Xslate" }),
            "include:\n" . "Hello, Xslate world!\n", "index.tx ($_)";

        is $tx->render('include2.tx', { file => "hello.tx", lang => "Xslate" }),
            "include2:\n" . "Hello, Xslate world!\n", 'index2.tx (literal)';

        is $tx->render('include2.tx', { file => "include.tx", lang => "Xslate" }),
            "include2:\n" . "include:\n" . "Hello, Xslate world!\n", 'index2.tx (var)';
    }

    eval {
        $tx->render('include2.tx', { file => "include2.tx", lang => "Xslate" });
    };
    like $@, qr/\bXslate\b/xms,   "recursion";
    like $@, qr/too \s+ deep/xms, "recursion";
}

done_testing;
