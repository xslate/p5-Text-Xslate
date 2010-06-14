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
);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    my %vars = (
        lang => 'Xslate',

        types => [qw(Str Int Object)],

        Types => [{ name => 'Void' }, { name => 'Bool' }],

        empty => [],

        data => [[qw(Perl)]],
    );
    is $tx->render_string($in, \%vars), $out, $msg or diag $in;
}

done_testing;
