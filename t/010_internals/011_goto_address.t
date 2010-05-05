#!perl -w
# NOTE: the optimizer could break goto addresses

use strict;
use Test::More;

use Text::Xslate;

#use Data::Dumper; $Data::Dumper::Indent = 1;

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
    #use Data::Dumper; $Data::Dumper::Useqq = 1;
    #is Dumper($x->render(\%vars)), Dumper($out);
    is $tx->render_string($in, \%vars), $out or do {
        require Data::Dumper;
        diag( Data::Dumper->new([$tx->render(\%vars)])->Useqq(1)->Dump );
    };
}

done_testing;
