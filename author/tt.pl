#!perl -w
use strict;
use Template;
use Smart::Comments;

my $t = Template->new();

$t->process(\<<'T', {}, \my $x);
    A
    [%- "[foo]" -%]
    B
T
### $x
