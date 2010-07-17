#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    ['Hello,
: for $types -> ($type) {
[<:= $type :>]
: }
world!'
        => "Hello,\n[Str]\n[Int]\n[Object]\nworld!"],

    ['Hello,
:for$types->($type){
[<:=$type:>]
:}
world!'
        => "Hello,\n[Str]\n[Int]\n[Object]\nworld!"],

    ['Hello,
: for $types -> ($type) {
:= $type
: }
world!'
        => "Hello,\nStrIntObjectworld!"],

    ['<<
: for $types -> ($t1) {
:    for $types -> ($t2) {
[<:=$t1:>|<:=$t2:>]
:    }
: }
>>', "<<
[Str|Str]
[Str|Int]
[Str|Object]
[Int|Str]
[Int|Int]
[Int|Object]
[Object|Str]
[Object|Int]
[Object|Object]
>>", "nested"],

    ['<<
: for $types -> ($t1) {
[<:=$t1:>]
: }
|
: for $types -> ($t1) {
[<:=$t1:>]
: }
>>', "<<
[Str]
[Int]
[Object]
|
[Str]
[Int]
[Object]
>>"],

    ['<<
: for $types -> ($lang) {
[<:=$lang:>]
: }
>> <:=$lang:>', "<<
[Str]
[Int]
[Object]
>> Xslate"],

    ['<<
: for $Types -> ($t) {
[<:=$t.name:>]
: }
>>', "<<
[Void]
[Bool]
>>"],

    ['<<
: for $empty -> ($t) {
[<:=$t.name:>]
: }
>>', "<<
>>"],

    [<<'T', <<'X'],
: macro foo -> $x {
:   for $x -> ($item) {
        <: $item :>
:   }
: }
: for $data -> ($item) {
:   foo($item)
: }
T
        Perl
X

    [<<'T', <<'X'],
: for $types -> ($item) {
    <: $~item :>
: }
T
    0
    1
    2
X


    # iterators

    [<<'T', <<'X'],
: for $types -> $item {
    : if (($~item+1) % 2) == 0 {
        Even
    : }
    : else {
        Odd
    : }
: }
T
        Odd
        Even
        Odd
X

    [<<'T', <<'X'],
: for $types -> ($item) {
    <: $~item.index :>
: }
T
    0
    1
    2
X

    [<<'T', <<'X'],
: for $types -> ($item) {
    <: $~item.count :>
: }
T
    1
    2
    3
X

    [<<'T', <<'X', 'is_first && is_last'],
: for $types -> ($item) {
    : if $~item.is_first {
---- first ----
    : }
    <: $~item.count :>
    : if $~item.is_last {
---- last ----
    : }
: }
T
---- first ----
    1
    2
    3
---- last ----
X

    [<<'T', <<'X', 'size'],
: for $types -> ($item) {
    <: $~item.size :>
: }
T
    3
    3
    3
X

    [<<'T', <<'X', 'max_index'],
: for $types -> ($item) {
    <: $~item.max_index :>
: }
T
    2
    2
    2
X


    [<<'T', <<'X', 'body'],
: for $types -> ($item) {
    <: $~item.body[ $~item.index ] :>
: }
T
    Str
    Int
    Object
X

    [<<'T', <<'X', 'peek_next'],
: for $types -> ($item) {
    <: $~item.peek_next // "(none)" :>
: }
T
    Int
    Object
    (none)
X

    [<<'T', <<'X', 'peek_prev'],
: for $types -> ($item) {
    <: $~item.peek_prev // "(none)" :>
: }
T
    (none)
    Str
    Int
X

    [<<'T', <<'X', 'cycle'],
: for [1, 2, 3, 4] -> ($item) {
    <: $~item.cycle("foo", "bar") :>
: }
T
    foo
    bar
    foo
    bar
X

    [<<'T', <<'X', 'cycle'],
: for [1, 2, 3, 4, 5, 6, 7, 8, 9] -> ($item) {
    <: $~item.cycle("foo", "bar", "baz") :>
: }
T
    foo
    bar
    baz
    foo
    bar
    baz
    foo
    bar
    baz
X

    [<<'T', <<'X', 'cycle'],
: for [1, 2, 3, 4] -> ($item) {
    <: $~item.cycle("foo", "bar", "baz") :>
: }
-------
: for [1, 2, 3, 4] -> ($item) {
    <: $~item.cycle("FOO", "BAR", "BAZ") :>
: }
T
    foo
    bar
    baz
    foo
-------
    FOO
    BAR
    BAZ
    FOO
X

    [<<'T', <<'X', 'nested $~i'],
: for $types -> $i {
:   for $types -> $j {
        [<: $~i.index :>][<: $~j.count :>]
:   }
: }
T
        [0][1]
        [0][2]
        [0][3]
        [1][1]
        [1][2]
        [1][3]
        [2][1]
        [2][2]
        [2][3]
X

    [<<'T', <<'X', 'nested $~i.cycle()'],
: for $types -> $i {
:   for $types -> $j {
        [<: $~i.cycle("a", "b") :>][<: $~j.cycle("c", "d", "e") :>]
:   }
: }
T
        [a][c]
        [a][d]
        [a][e]
        [b][c]
        [b][d]
        [b][e]
        [a][c]
        [a][d]
        [a][e]
X

);

my %vars = (
    lang => 'Xslate',

    types => [qw(Str Int Object)],

    Types => [{ name => 'Void' }, { name => 'Bool' }],

    empty => [],

    data => [[qw(Perl)]],
);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    is $tx->render_string($in, \%vars), $out, $msg or do {
        diag($in);

        my $code = $tx->compile($in);
        diag("// assembly");
        diag($tx->_compiler->as_assembly($code));
    };
}

done_testing;
