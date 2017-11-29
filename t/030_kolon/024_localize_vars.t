#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);
use lib "t/lib";
use Util;

my $tx = Text::Xslate->new(
    path  => [path],
    cache => 0,
    function => {
        vars => sub { return { lang => 'Perl' } },
    },
);

my @set = (
    # cascade

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

    [<<'T', { lang => 'Xslate' }, <<'X'],
: macro content -> { "Perl" }
: cascade myapp::base { lang => content() }
T
HEAD
    Hello, Perl world!
FOOT
X

    # include

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

    [<<'T', { lang => 'Xslate' }, <<'X', 'vars localized'],
: include "hello.tx" { __ROOT__.merge({ lang => 'Perl' }) }
Hello, <: $lang :> world!
T
Hello, Perl world!
Hello, Xslate world!
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'vars localized'],
: include "hello.tx" { vars() }
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

# macros over include

#$tx = Text::Xslate->new(
#    path => {
#        foo => <<'T',
#: macro add -> $x, $y { $x + $y }
#: include "bar" { add => add }
#T
#        bar => <<'T',
#: $add($foo, $bar)
#T
#});
#
#is $tx->render('bar', { add => sub { $_[0] + $_[1] }, foo => 10, bar => 15 }), 25;
#is $tx->render('foo', { foo => 10, bar => 20 }), 30;
#is $tx->render('foo', { foo => 20, bar => 25 }), 45;

done_testing;
