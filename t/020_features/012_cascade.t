#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use t::lib::Util;

my $tx = Text::Xslate->new(path => [path], cache => 0);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', 'without other components (bare name)'],
: cascade myapp::base
T
HEAD
    Hello, Xslate world!
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'without other components (string)'],
: cascade myapp::base
T
HEAD
    Hello, Xslate world!
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'one-level'],
: cascade myapp::base

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T
HEAD
    BEFORE
    Hello, Xslate world!
    AFTER
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'two-level without other components'],
: cascade myapp::derived
T
HEAD
    D-BEFORE
    Hello, Xslate world!
    D-AFTER
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'two-level'],
: cascade myapp::derived

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T
HEAD
    BEFORE
    D-BEFORE
    Hello, Xslate world!
    D-AFTER
    AFTER
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'one-level, around'],
: cascade myapp::base

: around hello -> {
    AROUND[
    : super
    ]AROUND
: }

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T
HEAD
    BEFORE
    AROUND[
    Hello, Xslate world!
    ]AROUND
    AFTER
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'two-level, around'],
: cascade myapp::derived

: around hello -> {
    AROUND[
    : super
    ]AROUND
: }

: before hello -> {
    BEFORE
: }
: after hello -> {
    AFTER
: }
T
HEAD
    BEFORE
    AROUND[
    D-BEFORE
    Hello, Xslate world!
    D-AFTER
    ]AROUND
    AFTER
FOOT
X

    [<<'T', { lang => 'Xslate' }, <<'X', 'override as around'],
: cascade myapp::base

: override hello -> {
    AROUND[
    : super
    ]AROUND
: }
T
HEAD
    AROUND[
    Hello, Xslate world!
    ]AROUND
FOOT
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg || $in
        for 1 .. 2;
}


done_testing;
