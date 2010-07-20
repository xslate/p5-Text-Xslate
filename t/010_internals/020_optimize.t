#!perl -w
# Ensure that the optimization works correctly
use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;

use t::lib::Util;
use File::Find;
use File::Basename;

if(!$Text::Xslate::Compiler::OPTIMIZE){
    plan skip_all => 'optimization is disabled';
}

my $tx = Text::Xslate->new(
    path  => [path],
    cache => 0,
);

sub asm_eq {
    my($x, $y, $msg) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $asm_x = $tx->compile("<: $x :>");
    my $asm_y = $tx->compile("<: $y :>");

    unless(is_deeply
            [ map { [$_->[0], $_->[1]] } @{$asm_x} ],
            [ map { [$_->[0], $_->[1]] } @{$asm_y} ], $msg) {
        diag "$x -> $y";
        diag explain($asm_x);
    }
}

asm_eq '1 + 1',             '2';
asm_eq '(1 + 1) * 3',       '6';
asm_eq '(1 + 1) * (1 + 3)', '8';

asm_eq '"foo" ~ "bar"', '"foobar"';

asm_eq '+^ 1', ~1;

asm_eq '10 min 20', '10';
asm_eq '10 max 20', '20';

asm_eq 'true  ? "ok" : "ng"', q{"ok"};
asm_eq 'false ? "ng" : "ok"', q{"ok"};

asm_eq '!!$a ? "ok" : "ng"', '$a ? "ok" : "ng"';

asm_eq '$a["foo"]',      '$a.foo';
asm_eq '$a["fo" ~ "o"]', '$a.foo';

asm_eq ' $a | html ', '$a';
asm_eq '($a | html)', '$a';
asm_eq 'html( $a ? "ok" : "ng")', '$a ? "ok" : "ng"';

# check whether all the noop are removed
find {
    wanted => sub {
        if(/\.tx$/ && !/bad_/) {
            open my $in, '<', $_ or die "$_ : $!";
            local $/;
            my $asm = $tx->compile(<$in>);
            ok !(grep{ $_->[0] eq 'noop' } @{$asm}),
                basename($_) . " does not include 'noop'";
        }
    },
    no_chdir => 1,
}, path;

done_testing;
