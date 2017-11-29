#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Util qw(p);
use lib "t/lib";
use Util;
use utf8;
{
    package MyArray;
    use Mouse;

    has size => (
        is      => 'rw',
        default => 42,
    );
}

my $tx = Text::Xslate->new(
    path => [path],
    function => {
        'hash::foo' => sub {
            return 'hash foo';
        },
        'array::foo' => sub {
            return 'array foo';
        },
        'scalar::foo' => sub {
            return 'scalar foo';
        },
    },
);

my @set = (
    # array
    ['<: $a.size() :>', { a => [] },        '0', 'for array'],
    ['<: $a.size() :>', { a => [0 .. 9] }, '10'],

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

    ['<: $a.sort().join(",") :>', { a => [] },        '', 'sort'],
    ['<: $a.sort().join(",") :>', { a => ['b', 'c', 'a'] }, 'a,b,c'],
    ['<: $a.sort().join(",") :>', { a => ['a', 'b', 'c'] }, 'a,b,c'],

    ['<: $a.merge(42).join(",") :>', { a => [1, 2, 3] }, '1,2,3,42'],
    ['<: $a.merge($a).join(",") :>', { a => [1, 2, 3] }, '1,2,3,1,2,3'],
    ['<: $a.merge([1, 2, 3]).join(",") :>', { a => [0] }, '0,1,2,3'],

    ['<: $a.first() :>', { a => [1, 2, 3] }, '1', 'get first element'],
    ['<: $a.first() :>', { a => [] }, '', 'first for empty array'],
    ['<: $a.last() :>', { a => [1, 2, 3] }, '3', 'get last element'],
    ['<: $a.last() :>', { a => [] }, '', 'last for empty array'],

    # hash
    ['<: $h.size() :>', { h => {} },        '0', 'for hash'],
    ['<: $h.size() :>', { h => {a => 1, b => 2, c => 3} }, '3'],

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

    [<<'T', { h => { } }, <<'X', 'kv (empty)' ],
<:
    for $h.kv() -> $pair {
        print $pair.key, "=", $pair.value, "\n";
    }
-:>
T
X

    [<<'T', { h => {a => 1, b => 2, c => 3} }, <<'X', 'reversed kv (pairs as struct)' ],
<:
    for $h.kv().reverse() -> $pair {
        print $pair.key, "=", $pair.value, "\n";
    }
-:>
T
c=3
b=2
a=1
X

    [<<'T', { h => {a => 1, b => 2, c => 3} }, <<'X', 'reversed kv (pairs as objects)' ],
<:
    for $h.kv().reverse() -> $pair {
        print $pair.key(), "=", $pair.value(), "\n";
    }
-:>
T
c=3
b=2
a=1
X

    [<<'T', { h => {a => 1, b => 2, c => 3} }, <<'X', 'merge' ],
<:
    for $h.merge({c => 30, d => 40}).kv() -> $pair {
        print $pair.key(), "=", $pair.value(), "\n";
    }
-:>
T
a=1
b=2
c=30
d=40
X

    ['<: $o.size() :>', { o => MyArray->new(size => 42) }, '42', 'object'],

    # register via function
    ['<: $v.foo() :>',  { v => { foo => 'bar'}}, 'hash foo' ],
    ['<: $v.foo() :>',  { v => [42]           }, 'array foo' ],
    ['<: $v.foo() :>',  { v => 'str'          }, 'scalar foo' ],

    ['<: {}.foo() :>', { v => { foo => 'bar'}}, 'hash foo' ],
    ['<: [].foo() :>',  { v => [42]           }, 'array foo' ],
    ['<: "".foo() :>',  { v => 'str'          }, 'scalar foo' ],
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}

$tx = Text::Xslate->new(
    function => {
        'array::size' => sub{
            my($array_ref) = @_;
            return @{$array_ref} + 100;
        },
    },
);

is $tx->render_string('<: [1, 2, 3].size() :>'), 103,
    'override builtin methods';

my $tx2 = Text::Xslate->new();
is $tx2->render_string('<: [1, 2, 3].size() :>'),  3,
    "doesn't affect other instances";

done_testing;
