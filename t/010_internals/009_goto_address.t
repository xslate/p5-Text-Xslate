#!perl -w
# NOTE: the optimizer could break goto addresses

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);

my $tx = Text::Xslate->new();

my @data = (
    [<<'T', "    [foo]\n" . "    [foo]\n"],
: if($value == "foo") {
    [<:= $value :>]
    [<:= $value :>]
: }
: else {
    [<:= $value :>]
    [<:= $value :>]
: }
T

    [<<'T', "    [foo]\n" . "    [foo]\n"],
: if($value == "bar") {
    [<:= $value :>]
    [<:= $value :>]
: }
: else {
    [<:= $value :>]
    [<:= $value :>]
: }
T

    [<<'T', "    [*foo]\n" . "    [*foo]\n"],
: if($value == "foo") {
    [<:= "*" ~ $value :>]
    [<:= "*" ~ $value :>]
: }
: else {
    [<:= "*" ~ $value :>]
    [<:= "*" ~ $value :>]
: }
T

    [<<'T', "    [*foo]\n" . "    [*foo]\n"],
: if($value == "bar") {
    [<:= "*" ~ $value :>]
    [<:= "*" ~ $value :>]
: }
: else {
    [<:= "*" ~ $value :>]
    [<:= "*" ~ $value :>]
: }
T
    [<<'T', "\ntrue\n\n"],
<: if 1 { :>
true
<: } else { :>
false
<: } :>
T
    [<<'T', "\nfalse\n\n"],
<: if 0 { :>
true
<: } else { :>
false
<: } :>
T

);


foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my %vars = (
        value => 'foo',
    );
    is $tx->render_string($in, \%vars), $out
        or diag( p($tx->render(\%vars)) );
}

done_testing;
