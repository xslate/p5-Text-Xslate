#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

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

    my %vars = (
        obj => Obj->new,
    );
    is $tx->render_string($in, \%vars), $out, $msg or diag $in;
}

done_testing;
