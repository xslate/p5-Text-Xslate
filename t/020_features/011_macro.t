#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $warn = '';
my $tx = Text::Xslate->new(
    warn_handler => sub { $warn .= "@_" },
);

my @set = (
    [<<'T', {lang => 'Xslate'}, <<'X', 'empty block'],
    A
    : block foo -> { }
    B
T
    A
    B
X

    [<<'T', {lang => 'Xslate'}, <<'X', 'template with a block'],
    A
    : block foo -> {
        Hello, <: $lang :> world!
    : }
    B
T
    A
        Hello, Xslate world!
    B
X

    [<<'T', {}, <<'X', 'template with bocks'],
    A
    : block foo -> {
        FOO
    : }
    B
    : block bar -> {
        BAR
    : }
    C
T
    A
        FOO
    B
        BAR
    C
X

    [<<'T', {}, <<'X', 'simplest macro'],
: macro foo -> {
    FOO
: }
: foo()
T
    FOO
X

    [<<'T', {x => "foo"}, <<'X', 'with an arg'],
: macro foo -> ($x) {
    FOO(<:$x:>)
: }
: foo(42)
T
    FOO(42)
X

    [<<'T', {}, <<'X', 'macro with args'],
: macro add -> $x, $y {
    [<: ($x + $y) :>]
: }
:add(10, 20) # 30
:add(11, 22) # 33
:add(15, 25) # 40
T
    [30]
    [33]
    [40]
X

    [<<'T', { VERSION => '1.012' }, <<'X', 'returns string'],
: macro signeture -> {
    This is foo version <:= $VERSION :>
: }
: "*" ~ signeture()
T
*    This is foo version 1.012
X
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg || $in
        for 1 .. 2;
}


my $out = eval {
    $tx->render_string(<<'T', {});
    : macro foo -> $arg {
        Hello <:= $arg :>!
    : }
    : foo()
T
};
is $out, "        Hello !\n";
like $warn, qr/Too few arguments/, 'prototype mismatch';
is $@, '';

done_testing;
