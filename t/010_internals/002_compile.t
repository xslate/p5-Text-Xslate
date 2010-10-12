#!perl -w

use strict;
use Test::More;

use Text::Xslate::Compiler;
use Text::Xslate::Util qw(p);

my $c = Text::Xslate::Compiler->new();

isa_ok $c, 'Text::Xslate::Compiler';

my @data = (
    ['Hello, world!', qr/Hello, world!/],
    ['Hello, <:= $lang :> world!', qr/\b lang \b/xms, qr/Hello, /, qr/ world!/],
    ['aaa <:= $bbb :> ccc <:= $ddd :>', qr/aaa/, qr/\b bbb \b/xms, qr/ccc/, qr/\b ddd \b/xms],

    ['<: for $data ->($item) { print $item; } :>', qr/\b for /xms, qr/\b data \b/xms  ],

    ['<: "foo" :>:<: "bar" :>', qr/ foo /xms, qr/ bar /xms, qr/ : /xms ],
);

foreach my $d(@data) {
    my($str, @patterns) = @{$d};

    my $code = p($c->compile($str));
    #note($code);

    foreach my $pat(@patterns) {
        like $code, $pat, $str;
    }
}

done_testing;
