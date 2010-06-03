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

    ['[% var.$xyz %]', 'value'],

    ['[% g["f"]["x"] %]', 'gfx', 'var["field"]']
);

{
    package A;
    use Any::Moose;

    has foo => (
        is => 'rw',
    );
}

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    last if $ENV{USE_TT} && defined($msg) && $msg eq 'var["field"]';

    my %vars = (
        var => { attr => 'value' },

        g => { f => { x => 'gfx' } },
        x => { f => { g => 'xfg' } },
        a => A->new(foo => 'bar'),

        ary => [10, 20, 30],

        foo => 'foo',

        xyz => 'attr',
    );

    is render_str($in, \%vars), $out, $msg;
}

done_testing;
