#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use lib "t/lib";
use Util;

my $tx = Text::Xslate->new(
    cache => 0,
    path  => [path],
);

my @data = (
    [<<'T', <<'X'],
    [<: "foo" if true :>]
T
    [foo]
X

    [<<'T', <<'X'],
    [<: "foo" if false :>]
T
    []
X

    [<<'T', <<'X'],
    [<: "foo" if $a[0] == 0 :>]
T
    [foo]
X

    [<<'T', <<'X'],
    [<: "foo" if $a[0] == 1 :>]
T
    []
X

    [<<'T', <<'X', 'include-if'],
    : include "hello.tx" if true
    : include "hello.tx" if true
T
Hello, Xslate world!
Hello, Xslate world!
X

    [<<'T', <<'X'],
    : include "hello.tx" if false
    : include "hello.tx" if false
T
X

);

my %vars = (
    lang => 'Xslate',
    a    => [ 0 .. 99 ],
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is $tx->render_string($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
