#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['<?= $value10 + 11 ?>', 21],
    ['<?= $value10 - 11 ?>', -1],

    ['<?= 12 + $value10 ?>', 22],
    ['<?= 12 - $value10 ?>',  2],

    ['<?= $value10 + $value20 ?>', 30],
    ['<?= $value0  + $value20 ?>', 20],

    ['<?= 1 + 3 + 5 ?>',  9],
    ['<?= 1 + 3 - 5 ?>', -1],
    ['<?= 1 - 3 + 5 ?>',  3],
    ['<?=(1 - 3)+ 5 ?>',  3],
    ['<?= 1 -(3 + 5)?>', -7],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (
        value0  =>  0,
        value10 => 10,
        value20 => 20,
    );
    is $x->render(\%vars), $out, $in;
}

done_testing;
