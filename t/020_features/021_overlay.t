#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new(path => [path]);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', 'without other components (bare name)'],
: cascade myapp::base with myapp::cfoo, myapp::cbar
T
HEAD
    FOO
    Hello, Xslate world!
    BAR
FOOT
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg || $in
        #for 1 .. 2;
}


done_testing;
