#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    ['<:= $var.field :>', 'value'],

    ['<:= $g.f.x :>',  'gfx'],
    ['<:= $x.f.g :>',  'xfg'],
    ['<:= $a.foo :>',  'bar'],

    ['<:= $ary.0 :>', 10],
    ['<:= $ary.1 :>', 20],
    ['<:= $ary.2 :>', 30],

    ['<:= $var["field"] :>',  'value'],

    ['<:= $g["f"]["x"] :>',  'gfx'],
    ['<:= $x["f"]["g"] :>',  'xfg'],
    ['<:= $a["foo"] :>',     'bar'],

    ['<:= $a[$foo] :>',      'bar'],
    ['<:= $a[$foo] :>',      'bar'],

    ['<:= $ary[0] :>', 10],
    ['<:= $ary[1] :>', 20],
    ['<:= $ary[2] :>', 30],

    ['<: constant foo   = "xxx"; $var[foo]   :>', "yyy"],
    ['<: constant field = "xxx"; $var[field] :>', "yyy"],

    ['<: constant foo   = "xxx"; $var.foo   :>', "FOO"],
    ['<: constant field = "xxx"; $var.field :>', "value"],

    ['<: $var.if :>',  'IF'],
    ['<: $var.nil :>', 'NIL'],
    ['<: $var.not :>', 'NOT'],
    ['<: $var.true :>', 'TRUE'],
    ['<: $var[true] :>', 'one'],

    ['<: $ary[false] :>', '10'],
    ['<: $ary[true]  :>', '20'],

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

my %vars = (
    var => {
        foo   => 'FOO',
        field => 'value',
        xxx   => 'yyy',
        if    => 'IF',
        nil   => 'NIL',
        true  => 'TRUE',
        not   => 'NOT',
        1     => 'one',
    },

    g => { f => { x => 'gfx' } },
    x => { f => { g => 'xfg' } },
    a => A->new(foo => 'bar'),

    ary => [10, 20, 30],

    foo => 'foo',
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    is $tx->render_string($in, \%vars), $out or diag $in;
}

done_testing;
