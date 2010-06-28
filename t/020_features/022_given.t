#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my $tmpl = <<'T';
: given $value {
:    when "foo" {
        FOO
:    }
:    when "bar" {
        BAR
:    }
:    default {
        BAZ
:    }
: }
T

my @set = (
    [$tmpl, { value => "foo" }, <<'X', 'given-when (1)'],
        FOO
X
    [$tmpl, { value => "bar" }, <<'X', 'given-when (2)'],
        BAR
X
    [$tmpl, { value => undef }, <<'X', 'given-when (default)'],
        BAZ
X

    [<<'T', { value => undef }, <<'X', 'default can be the first'],
: given $value {
:    default {
        BAZ
:    }
:    when "foo" {
        FOO
:    }
:    when "bar" {
        BAR
:    }
: }
T
        BAZ
X

    [<<'T', { value => undef }, <<'X'],
: given $value {
:    when 0 {
        ZERO
:    }
:    default {
        BAZ
:    }
: }
T
        BAZ
X

    [<<'T', { value => undef }, <<'X', 'default only'],
: given $value {
:    default {
        BAZ
:    }
: }
T
        BAZ
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (==)'],
: given $value -> $it {
:    when $it == 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 11 }, <<'X', 'logical expr (!=)'],
: given $value -> $it {
:    when $it != 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 9 }, <<'X', 'logical expr (<)'],
: given $value -> $it {
:    when $it < 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X


    [<<'T', { value => 10 }, <<'X', 'logical expr (<=)'],
: given $value -> $it {
:    when $it <= 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 11 }, <<'X', 'logical expr (>)'],
: given $value -> $it {
:    when $it > 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (>=)'],
: given $value -> $it {
:    when $it >= 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (||)'],
: given $value -> $it {
:    when $it == 9 || $it == 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (or)'],
: given $value -> $it {
:    when $it == 9 or $it == 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (&&)'],
: given $value -> $it {
:    when $it == 10 && $it >= 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (and)'],
: given $value -> $it {
:    when $it == 10 and $it >= 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (!)'],
: given $value -> $it {
:    when !($it > 10)  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10 }, <<'X', 'logical expr (not)'],
: given $value -> $it {
:    when not $it > 10  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => 10, x => 1 }, <<'X', 'non-logical expr'],
: given $value -> $it {
:    when $x + 9  {
        FOO
:    }
:    default {
        BAZ
:    }
: }
T
        FOO
X

    [<<'T', { value => undef }, <<'X', 'nil'],
: given $value -> $it {
:    when nil {
        FOO
:    }
:    default {
        UNLIKELY
:    }
: }
T
        FOO
X

    [<<'T', { value => 0 }, <<'X', 'nil'],
: given $value -> $it {
:    when nil {
        UNLIKELY
:    }
:    default {
        FOO
:    }
: }
T
        FOO
X

    [<<'T', { value => "foo" }, <<'X', 'extra spaces'],
<: given $value { :>


    <: when "foo" { :>
        FOO
    <: } :>


    <: default { :>
        unlikely
    <: } :>


<: } :>
T

        FOO
    
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}


done_testing;
