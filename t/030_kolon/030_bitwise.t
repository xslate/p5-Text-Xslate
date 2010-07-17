#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    ['<: 0x011       +| 0x100 :>', 0x111 ],
    ['<: $value0     +| 0x111 :>', 0x111 ],
    ['<: $value0x201 +| 0x111 :>', 0x311 ],
    ['<: 0x111 +| $value0x201 :>', 0x311 ],

    ['<: 0x011       +& 0x010 :>', 0x010 ],
    ['<: $value0     +& 0x111 :>', 0x000 ],
    ['<: $value0x201 +& 0x111 :>', 0x001 ],
    ['<: 0x111 +& $value0x201 :>', 0x001 ],

    ['<: 0x00101 +^ 0x00100 :>',   0x00001 ],
    ['<: 0x10100 +^ 0x10000 :>',   0x00100 ],
    ['<: $value0     +^ 0x111 :>', 0x111 ],
    ['<: $value0x201 +^ 0x111 :>', 0x310 ],
    ['<: 0x111 +^ $value0x201 :>', 0x310 ],

    ['<: +^0 :>',           ~0, 'const'],
    ['<: +^0x201 :>',       ~0x201, 'const'],
    ['<: +^$value0 :>',     ~0, 'var'],
    ['<: +^$value0x201 :>', ~0x201, 'var'],
);

my %vars = (
    value0     => 0,
    value0x201 => 0x201,
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is $tx->render_string($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
