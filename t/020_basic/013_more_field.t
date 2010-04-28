#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['<:= $var[ $foo && "bar" ] :>', 'BAR'],
    ['<:= $var[ $foo || "bar" ] :>', 'FOO'],

    ['<:= $var[ "foo" && "bar" ] :>', 'BAR'],
    ['<:= $var[ "foo" || "bar" ] :>', 'FOO'],

    ['<:= $var[ $foo == "foo" ? "bar" : "baz" ] :>', 'BAR'],
    ['<:= $var[ $foo != "foo" ? "bar" : "baz" ] :>', 'BAZ'],

    ['<:= $ary[ 0+0 ] :>', 10],
    ['<:= $ary[ 0+1 ] :>', 20],
    ['<:= $ary[ 1+1 ] :>', 30],

    ['<:= $ary[ 0-0 ] :>', 10],
    ['<:= $ary[ 2-1 ] :>', 20],
    ['<:= $ary[ 3-1 ] :>', 30],

    ['<:= $ary[ +0 ] :>', 10],
    ['<:= $ary[ -0 ] :>', 10],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (
        var => { foo => 'FOO', bar => 'BAR', baz => "BAZ" },

        ary => [10, 20, 30],

        foo => 'foo',
    );

    is $x->render(\%vars), $out, 'first:' . $in;
    is $x->render(\%vars), $out, 'second';
}

done_testing;
