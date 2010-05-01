#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    [<<'T', "A[foo]\nB\n", "prechomp(1)"],
A
<:- "[foo]" :>
B
T

    [<<'T', "    A[foo]\n    B\n", "prechomp(2)"],
    A
    <:- "[foo]" :>
    B
T

    [<<'T', "A\n[foo]B\n", "postchomp(1)"],
A
<: "[foo]" -:>
B
T

    [<<'T', "    A\n    [foo]    B\n", "postchomp(2)"],
    A
    <: "[foo]" -:>
    B
T


    [<<'T', "A[foo]B\n", "both(1)"],
A
<:- "[foo]" -:>
B
T

    [<<'T', "    A[foo]    B\n", "both(2)"],
    A
    <:- "[foo]" -:>
    B
T

);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (lang => 'Xslate', foo => "<bar>");

    is $x->render(\%vars), $out, $msg;
}

done_testing;
