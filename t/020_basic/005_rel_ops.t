#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['<?= $value10 == 10 ? 3 : 5 ?>', 3],
    ['<?= $value10 == 20 ? 3 : 5 ?>', 5],
    ['<?= $value20 == 10 ? 3 : 5 ?>', 5],
    ['<?= $value20 == 20 ? 3 : 5 ?>', 3],

    ['<?= $value10 == 10 && $value20 == 20 ? 3 : 5 ?>', 3],
    ['<?= $value10 == 10 || $value20 == 20 ? 3 : 5 ?>', 3],

    ['<?= ($value10 == 10 && $value20 == 20) ? 3 : 5 ?>', 3],
    ['<?= ($value10 == 10 || $value20 == 20) ? 3 : 5 ?>', 3],

    ['<?= ($value10 == 10 && $value20 == 20) && 5 ?>',  5],
    ['<?= ($value10 == 10 && $value20 != 20) && 5 ?>',  ''],
    ['<?= ($value10 == 10 && $value20 == 20) || 5 ?>',  1],
    ['<?= ($value10 == 10 && $value20 != 20) || 5 ?>',  5],
    ['<?= ($value10 != 10 && $value20 != 20) && 5 ?>',  ''],
    ['<?= ($value10 != 10 && $value20 != 20) || 5 ?>',  5],

    ['<?= ($value10 == 10 || $value20 == 20) && 5 ?>',  5],
    ['<?= ($value10 == 10 || $value20 != 20) && 5 ?>',  5],
    ['<?= ($value10 == 10 || $value20 == 20) || 5 ?>',  1],
    ['<?= ($value10 == 10 || $value20 != 20) || 5 ?>',  1],
    ['<?= ($value10 != 10 || $value20 != 20) && 5 ?>',  ''],
    ['<?= ($value10 != 10 || $value20 != 20) || 5 ?>',  5],

    ['<?= $value10 <   9 ?>', ''],
    ['<?= $value10 <  10 ?>', ''],
    ['<?= $value10 <  11 ?>',  1],
    ['<?= $value10 <=  9 ?>', ''],
    ['<?= $value10 <= 10 ?>',  1],
    ['<?= $value10 <= 11 ?>',  1],


    ['<?= $value10 >   9 ?>',  1],
    ['<?= $value10 >  10 ?>', ''],
    ['<?= $value10 >  11 ?>', ''],
    ['<?= $value10 >=  9 ?>',  1],
    ['<?= $value10 >= 10 ?>',  1],
    ['<?= $value10 >= 11 ?>', ''],
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
