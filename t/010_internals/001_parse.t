#!perl -w

use strict;
use Test::More;

use Text::Xslate::Parser;
use Text::Xslate::Util qw(p);

my $debug = 0;

my $parser = Text::Xslate::Parser->new();
isa_ok $parser, 'Text::Xslate::Parser';

my @data = (
    [''],
    ['Hello, world!', qr/"Hello, world!"/],
    ['Hello, <:= $lang :> world!', qr/ \$lang \b/xms, qr/"Hello, "/, qr/" world!"/],
    ['aaa <:= $bbb :> ccc <:= $ddd :>', qr/aaa/, qr/\$bbb/, qr/ccc/, qr/\$ddd/],

    ['<: for $data ->($item) { print $item; } :>', qr/\b for \b/xms, qr/\$data\b/, qr/\$item/ ],

    ["<p>:</p>",   qr{<p>:</p>}],
    ["<p> : </p>", qr{<p> : </p>}],

    [<<'T', qr/foo/, qr/item/, qr/data/],
: macro foo ->($x, $y) {
:   for $x -> ($item) {
        <: $item :>
:   }
: }
: for $data -> ($item) {
:   foo($item)
: }
T

    [<<'T'],
: if $foo {
    bar
: }
: else {
    baz
: }
T

    [';' x 10],

    [<<'T'],
: my $foo = {
:       bar => 42,
: };
T
);

foreach my $d(@data) {
    my($str, @patterns) = @{$d};

    note($str) if $debug;
    my $code = eval { p($parser->parse($str)) };
    note($code) if $debug;

    ok $code, 'parse'
        or diag $@;

    foreach my $pat(@patterns) {
        like $code, $pat;
    }
}

done_testing;
