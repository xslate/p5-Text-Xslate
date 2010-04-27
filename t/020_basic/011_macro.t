#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(string => <<'T', cache => 0);
A
: block foo -> {
    Hello, world!
: }
B
T

is $tx->render({}), "A\n    Hello, world!\nB\n", 'template with a block(1)';
is $tx->render({}), "A\n    Hello, world!\nB\n", 'template with a block(2)';


$tx = Text::Xslate->new(string => <<'T', cache => 0);
A
: block foo -> {
FOO
: }
B
: block bar -> {
BAR
: }
C
T

is $tx->render({}), "A\nFOO\nB\nBAR\nC\n", 'template with blocks(1)';
is $tx->render({}), "A\nFOO\nB\nBAR\nC\n", 'template with blocks(2)';

$tx = Text::Xslate->new(string => <<'T', cache => 0);
: macro add ->($x, $y) {
: "[" ~ ($x + $y) ~ "]"
: }
:= add(10, 20) # 30
:= add(11, 22) # 33
:= add(15, 25) # 40
T

is $tx->render({}), "[30][33][40]", 'macro';

done_testing;
