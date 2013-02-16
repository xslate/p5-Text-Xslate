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

    ['[% var.nil %]',      'This is nil', 'keyword as a field (nil)'],
    ['[% var.GET %]',      'This is GET', 'keyword as a field (GET)'],
    ['[% var.if %]',       'This is if',  'keyword as a field (if)'],
    ['[% var.not %]',      'This is not', 'keyword as a field (not)'],
);

{
    package A;
    use Mouse;

    has foo => (
        is => 'rw',
    );
}

my %vars = (
    var => {
        attr => 'value',
        nil => 'This is nil',
        GET => 'This is GET',
        if  => 'This is if',
        not => 'This is not',
    },

    g => { f => { x => 'gfx' } },
    x => { f => { g => 'xfg' } },
    a => A->new(foo => 'bar'),

    ary => [10, 20, 30],

    foo => 'foo',

    xyz => 'attr',
);
foreach my $pair(@data) {
    my($in, $out, $msg, $is_tterse_specific) = @$pair;

    last if $ENV{USE_TT} && $is_tterse_specific;

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
