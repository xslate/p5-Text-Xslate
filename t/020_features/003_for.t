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
>>"],

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
: macro foo ->($x, $y) {
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

);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my %vars = (
        lang => 'Xslate',

        types => [qw(Str Int Object)],

        Types => [{ name => 'Void' }, { name => 'Bool' }],

        empty => [],

        data => [[qw(Perl)]],
    );
    is $tx->render_string($in, \%vars), $out or diag $in;
}

done_testing;
