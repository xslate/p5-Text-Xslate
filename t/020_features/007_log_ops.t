#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['<:= $value10 == 10 ? 3 : 5 :>', 3],
    ['<:= $value10 == 20 ? 3 : 5 :>', 5],
    ['<:= $value20 == 10 ? 3 : 5 :>', 5],
    ['<:= $value20 == 20 ? 3 : 5 :>', 3],

    ['<:= $value10 == 10 && $value20 == 20 ? 3 : 5 :>', 3],
    ['<:= $value10 == 10 || $value20 == 20 ? 3 : 5 :>', 3],

    ['<:= ($value10 == 10 && $value20 == 20) ? 3 : 5 :>', 3],
    ['<:= ($value10 == 10 || $value20 == 20) ? 3 : 5 :>', 3],

    ['<:= ($value10 == 10 && $value20 == 20) && 5 :>',  5],
    ['<:= ($value10 == 10 && $value20 != 20) && 5 :>',  ''],
    ['<:= ($value10 == 10 && $value20 == 20) || 5 :>',  1],
    ['<:= ($value10 == 10 && $value20 != 20) || 5 :>',  5],
    ['<:= ($value10 != 10 && $value20 != 20) && 5 :>',  ''],
    ['<:= ($value10 != 10 && $value20 != 20) || 5 :>',  5],

    ['<:= ($value10 == 10 || $value20 == 20) && 5 :>',  5],
    ['<:= ($value10 == 10 || $value20 != 20) && 5 :>',  5],
    ['<:= ($value10 == 10 || $value20 == 20) || 5 :>',  1],
    ['<:= ($value10 == 10 || $value20 != 20) || 5 :>',  1],
    ['<:= ($value10 != 10 || $value20 != 20) && 5 :>',  ''],
    ['<:= ($value10 != 10 || $value20 != 20) || 5 :>',  5],

    ['<:= $value0  && 20 :>',  0 ],
    ['<:= $value10 && 20 :>', 20 ],
    ['<:= ""       && 20 :>', "" ],
    ['<:= (nil && 20) == nil :>', 1 ], # cannot print nil (undef)

    ['<:= $value0  and 20 :>',  0 ],
    ['<:= $value10 and 20 :>', 20 ],
    ['<:= ""       and 20 :>', "" ],
    ['<:= (nil and 20) == nil :>', 1 ], # cannot print nil (undef)

    ['<:= $value0  || 20 :>', 20 ],
    ['<:= $value10 || 20 :>', 10 ],
    ['<:= ""       || 20 :>', 20 ],
    ['<:= nil      || 20 :>', 20 ],

    ['<:= $value0  or 20 :>', 20 ],
    ['<:= $value10 or 20 :>', 10 ],
    ['<:= ""       or 20 :>', 20 ],
    ['<:= nil      or 20 :>', 20 ],

    ['<:= $value0  // 20 :>',  0 ],
    ['<:= $value10 // 20 :>', 10 ],
    ['<:= ""       // 20 :>', "" ],
    ['<:= nil      // 20 :>', 20 ],

    ['<:=    !$value0  || 20 :>',  1 ],
    ['<:=    !$value10 || 20 :>', 20 ],
    ['<:= not $value0  || 20 :>', "" ],
    ['<:= not $value10 || 0 :>',  "" ],

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
