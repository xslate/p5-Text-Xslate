#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @set = (
    [ <<'T', { data => [[qw(Perl)]] }, <<'X' ],
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <: $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
: }
T
        Hello, Perl world!
X

    [ <<'T', { data => [[qw(Perl Xslate)]] }, <<'X' ],
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <: $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
: }
T
        Hello, Perl world!
        Hello, Xslate world!
X

    [ <<'T', { data => [[qw(Perl Xslate)]] }, <<'X' ],
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <: $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
:   foo($item)
: }
T
        Hello, Perl world!
        Hello, Xslate world!
        Hello, Perl world!
        Hello, Xslate world!
X

    [ <<'T', { }, <<'X' ],
: macro foo ->($x) {
    <strong><:$x:></strong>
: }
: macro bar ->($x) {
:   foo($x)
: }
: foo("FOO")
: bar("BAR")
T
    <strong>FOO</strong>
    <strong>BAR</strong>
X

    [ <<'T', { }, <<'X', "nested call" ],
: macro foo ->($x) {
:   "[" ~ $x  ~ "]"
: }
<: foo(foo("FOO")) :>
T
[[FOO]]
X

    [ <<'T', { }, <<'X', "multi call" ],
: macro foo ->($x) {
:   "[" ~ $x  ~ "]"
: }
<: foo("FOO") ~ foo("BAR") :>
T
[FOO][BAR]
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg || $in
        for 1 .. 2;
}

done_testing;
