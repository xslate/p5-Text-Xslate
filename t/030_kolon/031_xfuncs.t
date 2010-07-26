#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(
    function => {
        'array::count' => sub {
            my($a, $cb) = @_;
            return scalar grep { $cb->($_) } @{$a};
        },
    },
);

my @data = (
    [<<'T', <<'X'],
    : macro upper50 -> $x { $x >= 50 }
    <: $a.count(upper50) :>
T
    50
X
    [<<'T', <<'X'],
    <: $a.count(-> $x { $x >=   0 }) :>
    <: $a.count(-> $x { $x >=  50 }) :>
    <: $a.count(-> $x { $x >= 100 }) :>
    <: $a.count(-> $x { $x == nil }) :>
    <: $a.count(-> $x { $x == 42  }) :>
T
    100
    50
    0
    0
    1
X
);

my %vars = (
    a => [ 0 .. 99 ],
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is $tx->render_string($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
