#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Util qw(p);

my $tx = Text::Xslate->new();

sub add_one {
    my($x) = @_;
    return $x + 1;
}

my @set = (
    [<<'T', { data => [1 .. 3], add_one => \&add_one }, <<'X'],
<: $data.map($add_one).join(', ') :>
T
2, 3, 4
X

    [<<'T', { data => [1 .. 3], add_one => \&add_one }, <<'X'],
<: $data.reverse().map($add_one).join(', ') :>
T
4, 3, 2
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
: macro add_one -> $x { $x + 1 }
<: $data.map(add_one).join(', ') :>
T
2, 3, 4
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
: macro add_one -> $x { $x + 1 }
: for $data -> $i {
    <: $data.map(add_one).join(', ') :>
: }
T
    2, 3, 4
    2, 3, 4
    2, 3, 4
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
    <: $data.map(-> $x { $x + 1 }).join(', ') :>
T
    2, 3, 4
X

    [<<'T', { data => [1 .. 3] }, <<'X'],
<: $data.map(-> $x { $x + 1 }).join(', ') :>/<: $data.map(-> $x { $x + 2 }).join(', ') :>/<: $data.map(-> $x { $x + 3 }).join(', ') :>
T
2, 3, 4/3, 4, 5/4, 5, 6
X


    [<<'T', { data => [1 .. 3] }, <<'X'],
: for $data.map(-> $x { $x + 1 }) -> $v {
    [<: $v :>]
: }
T
    [2]
    [3]
    [4]
X

    [<<'T', { data => ['<foo>', '<bar>'] }, <<'X'],
: for $data.map(-> $x { $x }) -> $v {
    [<: $v :>]
: }
T
    [&lt;foo&gt;]
    [&lt;bar&gt;]
X

    [<<'T', { data => ['a', 'c', 'b', 'd', 'a'] , cmp => sub { $_[1] cmp $_[0] }}, <<'X', 'sort with callback'],
: for $data.sort($cmp) -> $v {
    [<: $v :>]
: }
T
    [d]
    [c]
    [b]
    [a]
    [a]
X

    [<<'T', { data => [99, 20, 10, 1, 100] , cmp => sub { $_[0] <=> $_[1] }}, <<'X'],
: for $data.sort($cmp) -> $v {
    [<: $v :>]
: }
T
    [1]
    [10]
    [20]
    [99]
    [100]
X

    [<<'T', { data => [99, 20, 10, 1, 100]  }, <<'X'],
: for $data.sort(-> $x, $y { $x <=> $y }) -> $v {
    [<: $v :>]
: }
T
    [1]
    [10]
    [20]
    [99]
    [100]
X

    [<<'T', { data => [99, 20, 10, 1, 100]  }, <<'X'],
: for $data.sort(-> $x, $y { $x cmp $y }) -> $v {
    [<: $v :>]
: }
T
    [1]
    [10]
    [100]
    [20]
    [99]
X

    [<<'T', { data => [ { name => 'foo', value => 30 }, { name => 'foo', value => 20 }, { name => 'bar', value => 10 }]  }, <<'X'],
: for $data.sort(-> $x, $y { $x.name cmp $y.name or $x.value <=> $y.value }) -> $v {
    [<: $v.name :>=<: $v.value :>]
: }
T
    [bar=10]
    [foo=20]
    [foo=30]
X

    [<<'T', { data => [map { +{ value => $_ } } reverse 1 .. 10 ] }, <<'X'],
: for $data.sort(-> $x, $y { $x.value <=> $y.value }) -> $v {
    [<: $v.value :>]
: }
T
    [1]
    [2]
    [3]
    [4]
    [5]
    [6]
    [7]
    [8]
    [9]
    [10]
X

    [<<'T' x 2, { data => [map { +{ value => $_ } } reverse 1 .. 10 ] }, <<'X' x 2],
: for $data.sort(-> $x, $y { $x.value <=> $y.value }) -> $v {
    [<: $v.value :>]
: }
T
    [1]
    [2]
    [3]
    [4]
    [5]
    [6]
    [7]
    [8]
    [9]
    [10]
X


    [<<'T', { data => [1 .. 10] }, <<'X', 'reduce/sum'],
<: $data          .reduce(-> $a, $b { $a + $b }) :>
<: $data.reverse().reduce(-> $a, $b { $a + $b }) :>
T
55
55
X

    [<<'T', { data => [1..10] }, <<'X', 'reduce/min-max'],
<: $data          .reduce(-> $a, $b { $a min $b }) :>
<: $data.reverse().reduce(-> $a, $b { $a min $b }) :>
<: $data          .reduce(-> $a, $b { $a max $b }) :>
<: $data.reverse().reduce(-> $a, $b { $a max $b }) :>
T
1
1
10
10
X

    [<<'T', { }, <<'X'],
<: [].reduce(-> $a, $b { $a + $b }) // "nil" :>
<: [42].reduce(-> $a, $b { $a + $b }) // "nil" :>
<: [42, 3].reduce(-> $a, $b { $a + $b }) // "nil" :>
T
nil
42
45
X

    [<<'T', { add => sub { $_[0] + $_[1] } }, <<'X'],
<: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].reduce($add) // "nil" :>
T
55
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}

# TODO(?): builtin methods in XS dies if callback dies, while
#          those in PP doesn't.
#foreach (1 .. 2) {
#    my $out = eval {
#        $tx->render_string(<<'T', { data => [1, 2, 3 ]});
#            : macro bad_macro -> $x { bad_macro($x) }
#            : $data.map(bad_macro).join(', ')
#            : "Hello"
#T
#    };
#    is $out, '';
#    like $@, qr/too deep/, 'callback died';
#    is $tx->render_string('Hello, world!'), 'Hello, world!', 'restart';
#}


done_testing;
