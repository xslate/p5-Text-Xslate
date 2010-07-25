#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;

my $tx = Text::Xslate->new();

my @set = (
    [ <<'T', { data => [[qw(Perl)]] }, <<'X' ],
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <: $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
: }
T
        Hello, Perl world!
X

    [ <<'T', { data => [[qw(Perl Xslate)]] }, <<'X' ],
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <: $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
: }
T
        Hello, Perl world!
        Hello, Xslate world!
X

    [ <<'T', { data => [[qw(Perl Xslate)]] }, <<'X' ],
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <: $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
:   foo($item)
: }
T
        Hello, Perl world!
        Hello, Xslate world!
        Hello, Perl world!
        Hello, Xslate world!
X

    [ <<'T', { }, <<'X' ],
: macro foo ->($x) {
    <strong><:$x:></strong>
: }
: macro bar ->($x) {
:   foo($x)
: }
: foo("FOO")
: bar("BAR")
T
    <strong>FOO</strong>
    <strong>BAR</strong>
X

    [ <<'T', { }, <<'X', "nested call" ],
: macro foo ->($x) {
:   "[" ~ $x  ~ "]"
: }
<: foo(foo("FOO")) :>
T
[[FOO]]
X

    [ <<'T', { }, <<'X', "nested (arithmatic)" ],
: macro add ->($x, $y) { $x + $y }
<: add(1, 2) + add(10, 20) :>
T
33
X

    [ <<'T', { }, <<'X', "multi call" ],
: macro foo ->($x) {
:   "[" ~ $x  ~ "]"
: }
<: foo("FOO") ~ foo("BAR") ~ foo("BAZ") :>
T
[FOO][BAR][BAZ]
X

    [ <<'T', { }, <<'X', "nested multi call" ],
: macro foo ->($x) {
:   "[" ~ $x  ~ "]"
: }
<: foo(foo("FOO") ~ foo("BAR")) :>
T
[[FOO][BAR]]
X

    [ <<'T', { }, <<'X', "nested multi call (arithmatic)" ],
: macro add ->($x, $y) { $x + $y }
<: add(add(1, 2) + add(10, 20) + add(100, 200), 1000) :>
T
1333
X

    [ <<'T', { }, <<'X', "recursion" ],
    : macro factorial ->($x) {
    :   $x == 0 ? 1 : $x * factorial($x-1)
    : }
    <: factorial(0) :>
    <: factorial(1) :>
    <: factorial(2) :>
    <: factorial(3) :>
T
    1
    1
    2
    6
X

    [ <<'T', { }, <<'X', "filter operator" ],
    : macro factorial ->($x) {
    :   $x == 0 ? 1 : $x * factorial($x-1)
    : }
    <: 0 | factorial :>
    <: 1 | factorial :>
    <: 2 | factorial :>
    <: 3 | factorial :>
T
    1
    1
    2
    6
X

    [ <<'T', { }, <<'X', "a macro returns escaped string" ],
<: macro em ->($x) { :><em><: $x :></em><: } -:>
    <: "foo" | em        :>
    <: "bar" | em | raw  :>
    <: "baz" | em | html :>
T
    <em>foo</em>
    <em>bar</em>
    <em>baz</em>
X

    [ <<'T', { }, <<'X', "save macro" ],
<: macro em ->($x) { :><em><: $x :></em><: } -:>
: for [em] -> $m {
    <: $m("foo") :>
: }
T
    <em>foo</em>
X


    [<<'T', { value10 => 10 }, '100'],
: macro foo ->($x) { $x.foo }
: foo( { foo => $value10 == 10 ? 100 : $value10 == 20 ? 200 : 300 } )
T

    [<<'T', { value20 => 20 }, '200'],
: macro foo ->($x) { $x.foo }
: foo( { foo => $value20 == 10 ? 100 : $value20 == 20 ? 200 : 300 } )
T
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is eval { $tx->render_string($in, $vars) }, $out, $msg or diag $in;
    diag $@ if $@;
}

eval {
    $tx->render_string('<: foo("x") :>', {});
};
like $@, qr/\b foo \b/xms, "don't affect the parser";

eval {
    $tx->render_string(<<'T', {});
    : macro foo{
    :   foo()
    : }
    : foo()
T
};
like $@, qr/too deep/, 'deep recursion';
like $@, qr/\b foo \b/xms;

done_testing;
