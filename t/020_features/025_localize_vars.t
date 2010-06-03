#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);
use t::lib::Util;

my $tx = Text::Xslate->new(path => [path], cache => 0);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', 'cascade with local vars'],
: cascade myapp::base { lang => "Perl" }
T
HEAD
    Hello, Perl world!
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X'],
: cascade myapp::base { foo => 43*(1+2), lang => "Perl" }
T
HEAD
    Hello, Perl world!
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'include with vars'],
: include "hello.tx" { lang => "Perl" }
T
Hello, Perl world!
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'vars localized'],
: include "hello.tx" { lang => "Perl" }
Hello, <: $lang :> world!
T
Hello, Perl world!
Hello, Xslate world!
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    my $pre = p($vars);
    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);

    is p($vars), $pre, '$vars is not changed';
}


done_testing;
