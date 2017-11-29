#!perl -w
use strict;
use Test::More;

use lib "t/lib";
use TTSimple;

my @data = (
    [<<'T', <<'X', 'post if'],,
    {[% "foo" IF 1 %]}
    {[% "bar" IF 1 %]}
T
    {foo}
    {bar}
X

    [<<'T', <<'X'],
    {[% "foo" IF 0 %]}
    {[% "bar" IF 0 %]}
T
    {}
    {}
X

    [<<'T', <<'X', 'post unless'],
    {[% "foo" UNLESS 0 %]}
    {[% "bar" UNLESS 0 %]}
T
    {foo}
    {bar}
X

    [<<'T', <<'X'],
    {[% "foo" UNLESS 1 %]}
    {[% "bar" UNLESS 1 %]}
T
    {}
    {}
X


    [<<'T', <<'X', 'include if'],
[% INCLUDE "hello.tt" IF 1 -%]
[% INCLUDE "hello.tt" IF 1 -%]
T
Hello, Xslate world!
Hello, Xslate world!
X

    [<<'T', <<'X'],
[% INCLUDE "hello.tt" IF 0 -%]
[% INCLUDE "hello.tt" IF 0 -%]
T
X
);

my %vars = (
    lang  => 'Xslate',
    value => 10,
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;
    is render_str($in, \%vars), $out, $msg or diag($in);
}

done_testing;
