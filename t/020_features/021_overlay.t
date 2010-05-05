#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new(path => [path]);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', 'with a component'],
: cascade myapp::base with myapp::cfoo
T
HEAD
    FOO
    Hello, Xslate world!
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'with another component'],
: cascade myapp::base with myapp::cbar
T
HEAD
    Hello, Xslate world!
    BAR
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'with components'],
: cascade myapp::base with myapp::cfoo, myapp::cbar
T
HEAD
    FOO
    Hello, Xslate world!
    BAR
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'overlay'],
: cascade with myapp::cfoo, myapp::cbar
----
: block hello -> {
    This is template cascading!
: }
----
T
----
    FOO
    This is template cascading!
    BAR
----
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}


done_testing;
