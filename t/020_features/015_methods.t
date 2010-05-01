#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

{
    package Obj;
    use Mouse;

    sub join :method {
        my($self, $sep, @args) = @_;
        return join $sep, @args;
    }

    sub ok { 42 }
}

my @data = (
    [ <<'T', <<'X', "method call without args" ],
<: $obj.ok() :>
T
42
X

    [ <<'T', <<'X', "method call" ],
<: $obj.join(".") :>
T

X

    [ <<'T', <<'X', "method call" ],
<: $obj.join(".", "foo", "bar") :>
T
foo.bar
X

    [ <<'T', <<'X', "method call" ],
<: $obj.join(".", "foo", "bar", "baz") :>
T
foo.bar.baz
X

);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my $x = $tx->compile_str($in);

    my %vars = (
        obj => Obj->new,
    );
    is $x->render(\%vars), $out, $msg;
}

done_testing;
