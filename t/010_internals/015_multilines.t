#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();


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

    my $x = $tx->compile_str($in);

    my %vars = (
        xx => { yy => { zz => 42 } },
    );
    is $x->render(\%vars), $out, $msg;
}

done_testing;
