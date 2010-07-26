#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

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

    # no parens
    ['<:= $value10 == 10 && $value20 == 20 && 5 :>',  5],
    ['<:= $value10 == 10 && $value20 != 20 && 5 :>',  ''],
    ['<:= $value10 == 10 && $value20 == 20 || 5 :>',  1],
    ['<:= $value10 == 10 && $value20 != 20 || 5 :>',  5],
    ['<:= $value10 != 10 && $value20 != 20 && 5 :>',  ''],
    ['<:= $value10 != 10 && $value20 != 20 || 5 :>',  5],

    ['<:= $value10 == 10 || $value20 == 20 && 5 :>',  1],
    ['<:= $value10 == 10 || $value20 != 20 && 5 :>',  1],
    ['<:= $value10 == 10 || $value20 == 20 || 5 :>',  1],
    ['<:= $value10 == 10 || $value20 != 20 || 5 :>',  1],
    ['<:= $value10 != 10 || $value20 != 20 && 5 :>',  ''],
    ['<:= $value10 != 10 || $value20 != 20 || 5 :>',  5],

    ['<:= $value10 == 10 and $value20 == 20 and 5 :>',  5],
    ['<:= $value10 == 10 and $value20 != 20 and 5 :>',  ''],
    ['<:= $value10 == 10 and $value20 == 20 or  5 :>',  1],
    ['<:= $value10 == 10 and $value20 != 20 or  5 :>',  5],
    ['<:= $value10 != 10 and $value20 != 20 and 5 :>',  ''],
    ['<:= $value10 != 10 and $value20 != 20 or  5 :>',  5],

    ['<:= $value10 == 10 or  $value20 == 20 and 5 :>',  1],
    ['<:= $value10 == 10 or  $value20 != 20 and 5 :>',  1],
    ['<:= $value10 == 10 or  $value20 == 20 or  5 :>',  1],
    ['<:= $value10 == 10 or  $value20 != 20 or  5 :>',  1],
    ['<:= $value10 != 10 or  $value20 != 20 and 5 :>',  ''],
    ['<:= $value10 != 10 or  $value20 != 20 or  5 :>',  5],

    ['<:= $value10 == 10 or  $value20 == 20 and $value10 == 10 :>',  1],
    ['<:= $value10 == 10 or  $value20 != 20 and $value10 == 10 :>',  1],
    ['<:= $value10 == 10 or  $value20 == 20 or  $value10 == 10 :>',  1],
    ['<:= $value10 == 10 or  $value20 != 20 or  $value10 == 10 :>',  1],
    ['<:= $value10 != 10 or  $value20 != 20 and $value10 == 10 :>',  ''],
    ['<:= $value10 != 10 or  $value20 != 20 or  $value10 == 10 :>',  1],
    ['<:= $value10 == 10 or  $value20 == 20 or  $value10 != 10 :>',  1],

    ['<:= $value10 == 10 and $value20 == 20 and $value10 == 10 :>',  1],
    ['<:= $value10 == 10 and $value20 != 20 and $value10 == 10 :>',  ''],
    ['<:= $value10 == 10 and $value20 == 20 or  $value10 == 10 :>',  1],
    ['<:= $value10 == 10 and $value20 != 20 or  $value10 == 10 :>',  1],
    ['<:= $value10 != 10 and $value20 != 20 and $value10 == 10 :>',  ''],
    ['<:= $value10 != 10 and $value20 != 20 or  $value10 == 10 :>',  1],
    ['<:= $value10 == 10 and $value20 == 20 or  $value10 != 10 :>',  1],

    ['<: $value10 == 10 and $value10 == 10 and $value10 == 10 or $value10 != 10 :>', 1 ],
    ['<: $value10 == 10 and $value10 == 10 and $value10 == 10 or $value10 == 10 :>', 1 ],
    ['<: $value10 != 10 and $value10 == 10 and $value10 == 10 or $value10 == 10 :>', 1 ],

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

    ['<:= $value0  == 10 ? 100 :   0 || 200 :>', ( 0 == 10 ? 100 :   0 || 200 ) ],
    ['<:= $value10 == 10 ? 100 :   0 || 200 :>', (10 == 10 ? 100 :   0 || 200 ) ],
    ['<:= $value0  == 10 ?   0 : 100 || 200 :>', ( 0 == 10 ?   0 : 100 || 200 ) ],
    ['<:= $value10 == 10 ?   0 : 100 || 200 :>', (10 == 10 ?   0 : 100 || 200 ) ],

    ['<:= $value0  == 10 ? 100 :   0 or 200 :>', ( 0 == 10 ? 100 :   0 or 200 ) ],
    ['<:= $value10 == 10 ? 100 :   0 or 200 :>', (10 == 10 ? 100 :   0 or 200 ) ],
    ['<:= $value0  == 10 ?   0 : 100 or 200 :>', ( 0 == 10 ?   0 : 100 or 200 ) ],
    ['<:= $value10 == 10 ?   0 : 100 or 200 :>', (10 == 10 ?   0 : 100 or 200 ) ],

    ['<:   $value10 == 10 ? 100
         : $value10 == 20 ? 200
         : $value10 == 30 ? 300
         :                  400 :>', 100 ],

    ['<:   $value20 == 10 ? 100
         : $value20 == 20 ? 200
         : $value20 == 30 ? 300
         :                  400 :>', 200 ],

    ['<:   $value0  == 10 ? 100
         : $value0  == 20 ? 200
         : $value0  == 30 ? 300
         :                  400 :>', 400 ],

    [': defined($value0)      ? 1 : 0', 1],
    [': defined($no_such_var) ? 1 : 0', 0],
    [': defined $value0       ? 1 : 0', 1],
    [': defined $no_such_var  ? 1 : 0', 0],

    [': !defined($value0)      ? 1 : 0', 0],
    [': !defined($no_such_var) ? 1 : 0', 1],
    [': !defined $value0       ? 1 : 0', 0],
    [': !defined $no_such_var  ? 1 : 0', 1],

    [': defined $value10 + 10', defined 10 + 10],

    [': $undefined1 // $undefined2 // 10', 10],
    [': $undefined1 // ( $undefined2 // 10 )', 10],


    ['<:= ($value10 == 10 and $value20 == 20) ? "true" : "false":>',  "true"],
    ['<:= ($value10 == 10 and $value20 == 20 or  $value10 != 10) ? "true" : "false":>',  "true"],

    ['<:= ($value10 == 10 and $value20 == 20 or  $value10 != 10) ? "true" : "false":>
      <:= ($value10 != 10 and $value20 == 20 or  $value10 != 10) ? "true" : "false":>',  "true\n      false"],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;
    my %vars = (
        value0  =>  0,
        value10 => 10,
        value20 => 20,
    );
    is $tx->render_string($in, \%vars), $out or diag $in;

    if(0) {
        my $value0  = $vars{value0};
        my $value10 = $vars{value10};
        my $value20 = $vars{value20};
        $in =~ s/\A <:=? (.+) :> \z/$1/xms;
        $in =~ s/\A ://xms;
        $in =~ s/\b nil \b/undef/xmsg;
        no strict 'vars';
        is eval($in), $out or diag $@, $in;
    }
}

done_testing;
