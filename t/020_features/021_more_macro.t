#!perl -w

use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(string => <<'T', cache => 0);
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <:= $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
: }
T

is $tx->render({ data => [[qw(Perl Xslate)]] }), <<'T' for 1 .. 2;
        Hello, Perl world!
        Hello, Xslate world!
T

$tx = Text::Xslate->new(string => <<'T', cache => 0);
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <:= $item :> world!
:   }
: }
: for $data -> ($item) {
:   foo($item)
:   foo($item)
: }
T

is $tx->render({ data => [[qw(Perl Xslate)]] }), <<'T' for 1 .. 2;
        Hello, Perl world!
        Hello, Xslate world!
        Hello, Perl world!
        Hello, Xslate world!
T

done_testing;
