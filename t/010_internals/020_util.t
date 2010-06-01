#!perl -w

use strict;
use Test::More;

use Text::Xslate::Util qw(literal_to_value);

my @set = (
    [ q{"foo\\\\template"}, q{foo\template} ],

    [ q{"Hello, world\n"},  qq{Hello, world\n} ],
    [ q{"Hello, world\r"},  qq{Hello, world\r} ],
    [ q{"Hello, world\t"},  qq{Hello, world\t} ],

    [ q{'Hello, world\n'},  q{Hello, world\n} ],
    [ q{'Hello, world\r'},  q{Hello, world\r} ],
    [ q{'Hello, world\t'},  q{Hello, world\t} ],


    [ q{010},  010 ],
    [ q{0x10}, 0x10 ],
    [ q{0b10}, 0b10 ],

    [ q{-010},  -010 ],
    [ q{-0x10}, -0x10 ],
    [ q{-0b10}, -0b10 ],

    [ q{010_10},   010_10 ],
    [ q{0x10_10}, 0x10_10 ],
    [ q{0b10_10}, 0b10_10 ],

    [ q{0xDeadBeef}, 0xDeadBeef ],
);

foreach my $d(@set) {
    my($in, $out) = @{$d};
    is literal_to_value($in), $out, "literal: $in";
}

done_testing;
