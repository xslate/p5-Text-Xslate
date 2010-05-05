#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @set = (
    [<<'T', { value => 10 }, <<'X'],
<:
    if($value == 10) {
        print "Hello, world!";
    }
:>
T
Hello, world!
X

    [<<'T', { data => [1, 2, 3] }, <<'X'],
<:
    for $data -> $item {
        print "[" ~ $item ~ "]";
    }
:>
T
[1][2][3]
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}


done_testing;
