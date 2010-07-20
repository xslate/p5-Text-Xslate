#!perl -w
use strict;
use Template;
use Smart::Comments;

my $t = Template->new();

$t->process(\<<'T', {}, \my $x) or die $t->error, "\n";
    A
    [%- component -%]
    B
T
### $x
