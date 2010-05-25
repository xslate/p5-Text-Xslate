#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new(path => [path]);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X'],
: cascade myapp::base (lang => "Perl")
T
HEAD
    Hello, Perl world!
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X'],
: cascade myapp::base ( foo => 43*(1+2), lang => "Perl" )
T
HEAD
    Hello, Perl world!
FOOT
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}


done_testing;
