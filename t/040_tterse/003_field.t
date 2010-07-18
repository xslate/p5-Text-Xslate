#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    ['[% var.attr %]', 'value'],

    ['[% g.f.x %]',  'gfx'],
    ['[% x.f.g %]',  'xfg'],
    ['[% a.foo %]',  'bar'],

    ['[% ary.0 %]', 10],
    ['[% ary.1 %]', 20],
    ['[% ary.2 %]', 30],

    ['[% var.$xyz %]',           'value'],
    ['[% var.${xyz} %]',         'value'],
    ['[% var.${ xyz } %]',       'value'],
    ['[% var.${"attr"} %]',      'value'],

    # tterse specific features

    ['[% g["f"]["x"] %]', 'gfx', 'var["field"]', 1],
    ['[% var.${"at" _ "tr"} %]', 'value'],
);

{
    package A;
    use Any::Moose;

    has foo => (
        is => 'rw',
    );
}

foreach my $pair(@data) {
    my($in, $out, $msg, $is_tterse_specific) = @$pair;

    last if $ENV{USE_TT} && $is_tterse_specific;

    my %vars = (
        var => { attr => 'value' },

        g => { f => { x => 'gfx' } },
        x => { f => { g => 'xfg' } },
        a => A->new(foo => 'bar'),

        ary => [10, 20, 30],

        foo => 'foo',

        xyz => 'attr',
    );

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
