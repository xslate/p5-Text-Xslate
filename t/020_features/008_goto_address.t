#!perl -w
# NOTE: the optimizer could break goto addresses

use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

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
);


foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (
        value => 'foo',
    );
    is $x->render(\%vars), $out, $in;
}

done_testing;
