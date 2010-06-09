#!perl -w
BEGIN{ $ENV{XSLATE} ||= 'dump=asm;' }

use strict;
use Text::Xslate;

my $tx = Text::Xslate->new();

print $tx->render_string(<<'TX', { x => shift });
: macro add -> $x, $y { $x + $y }
: while(true) {
    : add(1, 2)
: }
TX
