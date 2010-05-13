#!perl -w

use strict;
use Test::More;

use Text::Xslate;

{
    package MyArray;
    use Mouse;

    has items => (
        is  => 'ro',
        isa => 'ArrayRef',

        default => sub { [] },
    );

    sub ITEMS{ shift->items() }
}

my $tx = Text::Xslate->new(
    #verbose => 2,
);

my @set = (
    # enumerable
    ['<: $a.size() :>', { a => [] },        '0', 'for array'],
    ['<: $a.size() :>', { a => [0 .. 9] }, '10'],

    ['<: $h.size() :>', { h => {} },        '0', 'for hash'],
    ['<: $h.size() :>', { h => {a => 1, b => 2, c => 3} }, '3'],

    ['<: $o.size() :>', { o => MyArray->new() },                   '0', 'for object'],
    ['<: $o.size() :>', { o => MyArray->new(items => [0 .. 9]) }, '10'],

    ['<: nil.size() :>', { }, '', 'nil.size() returns an empty string'],

    ['<: $a.join(",") :>', { a => [] },        ''  ],
    ['<: $a.join(",") :>', { a => [1, 2, 3] }, '1,2,3'],
    ['<: $a.join(",") :>', { a => ["foo","bar","baz"] }, 'foo,bar,baz'],

    ['<: $a.reverse()[0] :>', { a => [] },        ''  ],
    ['<: $a.reverse()[0] :>', { a => [1, 2, 3] }, '3'],
    ['<: $a.reverse()[0] :>', { a => ["foo","bar","baz"] }, 'baz'],

    ['<: $a.reverse().join(",") :>', { a => [] },        '', 'chained'],
    ['<: $a.reverse().join(",") :>', { a => [1, 2, 3] }, '3,2,1'],
    ['<: $a.reverse().join(",") :>', { a => ["foo","bar","baz"] }, 'baz,bar,foo'],

    # kv
    ['<: $h.keys().join(",") :>', { h => {} }, '', 'keys'],
    ['<: $h.keys().join(",") :>', { h => {a => 1, b => 2, c => 3} }, 'a,b,c'],

    ['<: $h.values().join(",") :>', { h => {} }, '', 'values'],
    ['<: $h.values().join(",") :>', { h => {a => 1, b => 2, c => 3} }, '1,2,3'],

    [<<'T', { h => {a => 1, b => 2, c => 3} }, <<'X', 'kv' ],
<:
    for $h.kv() -> $pair {
        print $pair.key, "=", $pair.value, "\n";
    }
-:>
T
a=1
b=2
c=3
X

    [<<'T', { h => {a => 1, b => 2, c => 3} }, <<'X', 'reversed kv' ],
<:
    for $h.reverse() -> $pair {
        print $pair.key, "=", $pair.value, "\n";
    }
-:>
T
c=3
b=2
a=1
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}


done_testing;
