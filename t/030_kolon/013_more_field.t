#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

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

    ['<:= $ary[ +0.0 ] :>', 10],
    ['<:= $ary[ -0.0 ] :>', 10],

    ['<:= $var[ $ary[3] ] :>', "FOO"],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my %vars = (
        var => { foo => 'FOO', bar => 'BAR', baz => "BAZ" },

        ary => [10, 20, 30, "foo"],

        foo => 'foo',
    );

    is $tx->render_string($in, \%vars), $out or diag $in;
}

done_testing;
