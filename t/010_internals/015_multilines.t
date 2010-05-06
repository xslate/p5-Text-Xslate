#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();


my @data = (
    [ <<'T', <<'X'],
<: $xx.yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx
    .yy.zz :>
T
42
X
    [ <<'T', <<'X'],
<: $xx # comment
    .yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx.
    yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx. # comment
    yy.zz :>
T
42
X

    [ <<'T', <<'X'],
<: $xx
    .
    yy
    .
    zz :>
T
42
X

);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my %vars = (
        xx => { yy => { zz => 42 } },
    );
    is $tx->render_string($in, \%vars), $out, $msg;
}

done_testing;
