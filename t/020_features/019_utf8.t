#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use utf8;

use FindBin qw($Bin);
use t::lib::Util;

my $tx = Text::Xslate->new(
    string => <<'TX',
ようこそ <:= $value :> の世界へ！
TX
);

is $tx->render({ value => "エクスレート" }),
    "ようこそ エクスレート の世界へ！\n", "utf8";

is $tx->render({ value => "Xslate" }),
    "ようこそ Xslate の世界へ！\n", "utf8";

for(1 .. 2) {
    $tx = Text::Xslate->new(
        file => "hello_utf8.tx",
        path => [path],
    );

    is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", "in files";
}

for(1 .. 2) {
    $tx = Text::Xslate->new(
        file        => "hello_utf8.tx",
        path        => [path],
        input_layer => ":encoding(utf-8)",
    );

    is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", "in files";
}


unlink "$Bin/../template/hello_utf8.txc";

done_testing;
