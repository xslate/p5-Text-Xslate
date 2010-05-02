#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

use constant { T => 1, F => 0 };

my @data = (
    ['<:= $value10 == 10 :>', T],
    ['<:= $value10 == 20 :>', F],
    ['<:= $value20 == 10 :>', F],
    ['<:= $value20 == 20 :>', T],

    ['<:= $value10 != 10 :>', !T],
    ['<:= $value10 != 20 :>', !F],
    ['<:= $value20 != 10 :>', !F],
    ['<:= $value20 != 20 :>', !T],

    ['<:= $value10 <   9 :>', F],
    ['<:= $value10 <  10 :>', F],
    ['<:= $value10 <  11 :>', T],
    ['<:= $value10 <=  9 :>', F],
    ['<:= $value10 <= 10 :>', T],
    ['<:= $value10 <= 11 :>', T],


    ['<:= $value10 >   9 :>', T],
    ['<:= $value10 >  10 :>', F],
    ['<:= $value10 >  11 :>', F],
    ['<:= $value10 >=  9 :>', T],
    ['<:= $value10 >= 10 :>', T],
    ['<:= $value10 >= 11 :>', F],


    ['<:= "foo" == "foo" :>', T],
    ['<:= "foo" == "bar" :>', F],
    ['<:= "foo" != "foo" :>', F],
    ['<:= "foo" != "bar" :>', T],


    ['<:= 3.14 == 3.14   :>', T],
    ['<:= 3.14 == 3.13   :>', F],
    ['<:= 3    == 3      :>', T],
    ['<:= 3    == 2      :>', F],

    ['<:= "0" == "0E0" :>', F],
    ['<:= "0" == ""    :>', F],

    ['<:= "foo" == nil :>', F],
    ['<:= ""    == nil :>', F],
    ['<:= 0     == nil :>', F],
    ['<:= nil   == nil :>', T],

    ['<:= "foo" != nil :>', T],
    ['<:= ""    != nil :>', T],
    ['<:= 0     != nil :>', T],
    ['<:= nil   != nil :>', 0],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;
    my $x = $tx->compile_str($in);

    my %vars = (
        value0  =>  0,
        value10 => 10,
        value20 => 20,
    );
    is !!$x->render(\%vars), !!$out;
}

done_testing;
