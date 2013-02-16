#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new(verbose => 2);

{
    package Obj;
    use Mouse;

    sub join :method {
        my($self, $sep, @args) = @_;
        return join $sep, @args;
    }

    sub ok { 42 }

    sub nil   { 'nil' }
    sub true  { 'true' }
    sub false { 'false' }
}
{
    package Anything;
    use Mouse;

    sub AUTOLOAD {
        our $AUTOLOAD;
    }
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


    [ <<'T', <<'X', "method call" ],
<: $obj.join(".", "foo", "bar", "baz") :>
T
foo.bar.baz
X

    [ <<'T', <<'X', "AUTOLOAD" ],
    <: $any.foo :>
    <: $any.bar :>
    <: $any.baz() :>
T
    Anything::foo
    Anything::bar
    Anything::baz
X

    [ <<'T', <<'X', "keywords" ],
    <: $obj.nil() :>
    <: $obj.true() :>
    <: $obj.false() :>
T
    nil
    true
    false
X

);

my %vars = (
    obj => Obj->new,
    any => Anything->new,
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is $tx->render_string($in, \%vars), $out, $msg or diag $in;
}

done_testing;
