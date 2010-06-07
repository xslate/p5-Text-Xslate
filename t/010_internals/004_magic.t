#!perl -w

use strict;
use Test::More;

use Text::Xslate;

use Tie::Array;
use Tie::Hash;

# for ARRAY

my @a;
tie @a, 'Tie::StdArray';

my %h;
tie %h, 'Tie::StdHash';

my $tx = Text::Xslate->new();

my @set = (
    [<<'T', [{ first => 'foo',  second => 'bar' }], <<'X'],
: for $data ->($item) {
    [<:=$item.first:>][<:=$item.second:>]
: }
T
    [foo][bar]
X

    [<<'T', [qw(foo bar baz)], <<'X'],
    <: $data.size() :>
T
    3
X

    [<<'T', [qw(foo bar baz)], <<'X'],
    <: $data.join(', ') :>
T
    foo, bar, baz
X

    [<<'T', [qw(foo bar baz)], <<'X'],
    <: $data.reverse().join(', ') :>
T
    baz, bar, foo
X


    [<<'T', { foo => 10, bar => 20 }, <<'X'],
    <: $data.keys().join(', ') :>
T
    bar, foo
X

    [<<'T', { foo => 10, bar => 20 }, <<'X'],
    <: $data.values().join(', ') :>
T
    20, 10
X

    [<<'T', { foo => 10, bar => 20 }, <<'X'],
    : for $data.kv() -> $pair {
    <: $pair.key :>=<: $pair.value :>
    : }
T
    bar=20
    foo=10
X

);

foreach my $d(@set) {
    my($in, $data, $out, $msg) = @$d;

    if(ref $data eq 'ARRAY') {
        @a = @{$data};
        $data = \@a;
    }
    else {
        %h = %{$data};
        $data = \%h;
    }
    is $tx->render_string($in, { data => $data }), $out, $msg
        or diag($in);
}

# for toplevel HASH

@a = (
    { first => 'aaa', second => 'bbb' },
    { first => 'ccc', second => 'ddd' },
);

%h = (data => \@a);

is $tx->render_string(<<'T', \%h), <<'X', "tied hash" for 1 .. 2;
: for $data ->($item) {
    [<:=$item.first:>][<:=$item.second:>]
: }
T
    [aaa][bbb]
    [ccc][ddd]
X

done_testing;
