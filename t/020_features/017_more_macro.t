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

    [ <<'T', { }, <<'X', "multi call" ],
: macro foo ->($x) {
:   "[" ~ $x  ~ "]"
: }
<: foo("FOO") ~ foo("BAR") :>
T
[FOO][BAR]
X

    [ <<'T', { }, <<'X', "nexted multi call" ],
: macro foo ->($x) {
:   "[" ~ $x  ~ "]"
: }
<: foo(foo("FOO") ~ foo("BAR")) :>
T
[[FOO][BAR]]
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
    <: "foo" | em | raw  :>
    <: "bar" | em | html :>
T
    <em>foo</em>
    <em>bar</em>
X

    [ <<'T', { }, <<'X', "save macro" ],
<: macro em ->($x) { :><em><: $x :></em><: } -:>
: for [em] -> $m {
    <: $m("foo") :>
: }
T
    <em>foo</em>
X

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
