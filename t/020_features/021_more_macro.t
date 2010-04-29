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
:=   foo($item)
: }
T

is $tx->render({ data => [[qw(Perl Xslate)]] }), <<'T', "t$_" for 1 .. 2;
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
:=   foo($item)
:=   foo($item)
: }
T

is $tx->render({ data => [[qw(Perl Xslate)]] }), <<'T', "t$_" for 1 .. 2;
        Hello, Perl world!
        Hello, Xslate world!
        Hello, Perl world!
        Hello, Xslate world!
T

$tx = Text::Xslate->new(string => <<'T', cache => 0);
A
: macro foo ->($x) {
:   for $x -> ($item) {
        Hello, <:= $item :> world!
:   }
: }
: macro bar ->($x) {
:=   foo($x)
: }
: for $data -> ($item) {
:=   bar($item)
:=   bar($item)
: }
B
T

is $tx->render({ data => [[qw(Perl Xslate)]] }), <<'T', "t$_" for 1 .. 2;
A
        Hello, Perl world!
        Hello, Xslate world!
        Hello, Perl world!
        Hello, Xslate world!
B
T

$tx = Text::Xslate->new(string => <<'T', cache => 0);
: macro foo ->($x) {
    <strong><:=$x:></strong>
: }
: macro bar ->($x) {
:=   foo($x)
: }
:= foo("FOO")
:= bar("BAR")
T

is $tx->render({ data => [[qw(Perl Xslate)]] }), <<'T', "t$_" for 1 .. 2;
    <strong>FOO</strong>
    <strong>BAR</strong>
T

# XXX: is it useful?
#
#$tx = Text::Xslate->new(string => <<'T', cache => 0);
#: macro foo ->($x) {
#        <strong><:=$x:></strong>
#: }
#: around foo ->($x) {
#    --------------------
#    : super
#    --------------------
#: }
#:= foo("FOO")
#T
#
#is $tx->render({ data => [[qw(Perl Xslate)]] }), <<'T', "t$_" for 1 .. 2;
#    --------------------
#    <strong>FOO</strong>
#    --------------------
#T


done_testing;
