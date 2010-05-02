#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    ['<:= $var.attr :>', 'value'],

    ['<:= $g.f.x :>',  'gfx'],
    ['<:= $x.f.g :>',  'xfg'],
    ['<:= $a.foo :>',  'bar'],

    ['<:= $ary.0 :>', 10],
    ['<:= $ary.1 :>', 20],
    ['<:= $ary.2 :>', 30],

    ['<:= $var["attr"] :>',  'value'],

    ['<:= $g["f"]["x"] :>',  'gfx'],
    ['<:= $x["f"]["g"] :>',  'xfg'],
    ['<:= $a["foo"] :>',     'bar'],

    ['<:= $a[$foo] :>',      'bar'],

    ['<:= $ary[0] :>', 10],
    ['<:= $ary[1] :>', 20],
    ['<:= $ary[2] :>', 30],

    ['<: $a :>', 'as_string'],
);

{
    package A;
    use Mouse;
    use overload '""' => sub{ "as_string" };

    has foo => (
        is => 'rw',
    );
}

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (
        var => { attr => 'value' },

        g => { f => { x => 'gfx' } },
        x => { f => { g => 'xfg' } },
        a => A->new(foo => 'bar'),

        ary => [10, 20, 30],

        foo => 'foo',
    );

    is $x->render(\%vars), $out, 'first:' . $in;
    is $x->render(\%vars), $out, 'second';
}

done_testing;
