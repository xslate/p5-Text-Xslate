#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['<:= $value | uc :>', "FOO"],
    ['<:= uc($value) :>',  "FOO"],
    ['<:= sprintf("<%s>", $value) :>',      "&lt;foo&gt;"],
    ['<:= sprintf("<%s>", $value | uc) :>', "&lt;FOO&gt;"],
    ['<:= sprintf("<%s>", uc($value)) :>',  "&lt;FOO&gt;"],

    ['<:= sprintf("%s %s", uc($value), uc($value)) :>',  "FOO FOO"],
);

$tx->constant(uc      => sub{ uc $_[0] });
$tx->constant(sprintf => sub{ sprintf shift, @_ });

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (
        value => 'foo',
    );
    is $x->render(\%vars), $out, $in;
}

done_testing;
