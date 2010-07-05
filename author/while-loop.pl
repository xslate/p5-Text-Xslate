#!perl -w
BEGIN{ $ENV{XSLATE} ||= 'dump=asm;' }

use strict;
use Text::Xslate;

my $tx = Text::Xslate->new(
    function => { f => sub { undef } },
);

print $tx->render_string(<<'TX', { x => shift });
: macro add -> $x, $y { $x + $y }
: while(true) {
    : if(add(1, 2) > 0) { }
: }
TX
