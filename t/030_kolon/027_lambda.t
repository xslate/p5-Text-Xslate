#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Util qw(p);

my $tx = Text::Xslate->new();

my @set = (
    [<<'T', {}, <<'X'],
<: -> $x { $x + 10 }(0) :>
<: -> $x { $x + 10 }(1) :>
<: -> $x { $x + 10 }(2) :>
T
10
11
12
X
    [<<'T', {}, <<'X'],
<: my $y = 10; -> $x { $x + $y }(15) :>
T
25
X

    [<<'T', {}, <<'X'],
<: my $add10 = -> $x { $x + 10 }; $add10(20) :>
T
30
X

    [<<'T', {}, <<'X'],
<: constant add10 = -> $x { $x + 10 }; add10(20) :>
T
30
X

    [<<'T', {}, <<'X'],
: for [1, 2, 3] -> $v {
<: my $addv = -> $x { $x + $v }; $addv(20) :>
: }
T
21
22
23
X


);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}


done_testing;
