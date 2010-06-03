#!perl -w
BEGIN{ $ENV{XSLATE} ||= 'dump=asm;' }

use strict;
use Text::Xslate;

my $tx = Text::Xslate->new();
print $tx->render_string(<<'TX', { x => shift });
<:= $x == 42 ?   0 : 100 or 200 :>
TX
