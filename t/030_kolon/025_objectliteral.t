#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);
use lib "t/lib";
use Util;

my $tx = Text::Xslate->new(path => [path]);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', "=> as ,"],
: macro foo -> $a, $b { $a ~ "\n" }
: foo("foo" => "b")
T
foo
X

    [<<'T', { lang => 'Xslate' }, <<'X', "lhs can be bare"],
: macro foo -> $a, $b { $a ~ "\n" }
: foo(foo => "b")
: foo(bar => "b")
: foo(raw => "b")
: foo(if  => "b")
: foo(not => "b")
T
foo
bar
raw
if
not
X

    # array

    [<<'T', { lang => 'Xslate' }, '0', "empty array literal"],
: macro foo -> $a { $a.size() }
: foo([])
T

    [<<'T', { lang => 'Xslate' }, <<'X', "array literal"],
: macro foo -> $a { $a.0 ~ "\n" }
: foo(["foo", "bar", "baz"])
T
foo
X

    [<<'T', { lang => 'Xslate' }, <<"X"],
: for [1, 2, 3] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: ["foo", $lang].1
T

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: (["foo", $lang]).1
T

    # hash

    [<<'T', { lang => 'Xslate' }, '0', "empty hash literal"],
: macro foo -> $a { $a.size() }
: foo({})
T

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: ({foo => $lang, bar => 42}).foo
T

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: ({ bar => 42, foo => $lang }).foo
T

    [<<'T', { lang => 'Xslate' }, <<"X"],
: for { foo => 10, bar => 20 }.kv() -> $pair {
    <: $pair.key :>=<: $pair.value :>
: }
T
    bar=20
    foo=10
X

    [<<'T', { lang => 'Xslate' }, <<"X", "keywords"],
: for { not => 10, for => 20 }.kv() -> $pair {
    <: $pair.key :>=<: $pair.value :>
: }
T
    for=20
    not=10
X

    [<<'T', { lang => 'Xslate' }, <<"X", "underbars"],
: for { foo_bar => 10, _baz => 20 }.kv() -> $pair {
    <: $pair.key :>=<: $pair.value :>
: }
T
    _baz=20
    foo_bar=10
X

    [<<'T', { lang => 'Xslate' }, <<"X", "nested"],
: for [ [1], [2], [3] ] -> $i {
    <: $i[0] :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "nested"],
: for [ { value => 1 }, { value => 2 }, { value => 3 } ] -> $i {
    <: $i.value :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "extra commas"],
: for [ 1, 2, 3, ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "newlines"],
: for [
:        1,
:        2,
:        3,
:    ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "more extra commas"],
: for [ ,,1,,2,,3,, ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "range"],
: for [ 1 .. 5 ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
    4
    5
X

    [<<'T', { lang => 'Xslate' }, <<"X", "range"],
: for [ 1 .. 3 + 1 ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
    4
X

    [<<'T', { lang => 'Xslate' }, <<"X", "range 'a' .. 'c'"],
: for [ 'a' .. 'c' ] -> $i {
    <: $i :>
: }
T
    a
    b
    c
X

    [<<'T', { lang => 'Xslate' }, <<"X", "range 0 .. 2, 'a' .. 'c'"],
: for [ 0 .. 2, 'a' .. 'c' ] -> $i {
    <: $i :>
: }
T
    0
    1
    2
    a
    b
    c
X

    [<<'T', { lang => 'Xslate' }, <<"X", "range"],
: for [ 2 .. 0 ] -> $i {
    <: $i :>
: }
T
X

    [<<'T', { lang => 'Xslate' }, <<"X", "range"],
: for [ "z" .. "a" ] -> $i {
    <: $i :>
: }
T
    z
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}


done_testing;
