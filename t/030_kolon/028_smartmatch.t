#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(verbose => 2);

my @set = (
    [<<'T', { value => "foo" }, <<'X'],
    <: $value ~~ "foo" ? "matched" : "unmatched" :>
T
    matched
X

    [<<'T', { value => "" }, <<'X'],
    <: $value ~~ nil ? "matched" : "unmatched" :>
T
    unmatched
X

    [<<'T', { value => "foo" }, <<'X'],
: given $value {
:    when ["foo", "bar", nil] {
        matched
:    }
:    default {
        unmatched
:    }
: }
T
        matched
X

    [<<'T', { value => undef }, <<'X'],
: given $value {
:    when ["foo", "bar", nil] {
        matched
:    }
:    default {
        unmatched
:    }
: }
T
        matched
X

    [<<'T', { value => "baz" }, <<'X'],
: given $value {
:    when ["foo", "bar", nil] {
        matched
:    }
:    default {
        unmatched
:    }
: }
T
        unmatched
X

    [<<'T', { value => "foo" }, <<'X'],
: given $value {
:    when { foo => nil, bar => nil } {
        matched
:    }
:    default {
        unmatched
:    }
: }
T
        matched
X

    [<<'T', { value => "bar" }, <<'X'],
: given $value {
:    when { foo => nil, bar => nil } {
        matched
:    }
:    default {
        unmatched
:    }
: }
T
        matched
X

    [<<'T', { value => "baz" }, <<'X'],
: given $value {
:    when { foo => nil, bar => nil } {
        matched
:    }
:    default {
        unmatched
:    }
: }
T
        unmatched
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}


done_testing;
