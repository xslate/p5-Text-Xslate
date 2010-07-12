#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(html_escape);
use Text::Xslate::Util qw(p);
use Data::Dumper;
use Time::localtime qw(localtime);

my $tx = Text::Xslate->new(
    module => [
        'Data::Dumper',
        'Time::localtime' => [qw(localtime)],
        'Scalar::Util'    => [qw(blessed)],
    ],
    function => {
        blessed => sub{ 42 }, # override
    },
);

my @set = (
    [
        '<: Dumper($d) :>',
        { d => { foo => 'bar', baz => [42] } },
        Dumper({ foo => 'bar', baz => [42] }),
    ],
    [
        '<: localtime($t).mday :>',
        { t => $^T },
        localtime($^T)->mday,
    ],
    [
        '<: blessed($x) :>',
        { x => bless {} },
        42,
        'function overrides the imported',
    ],
    [
        '<: dump($x) :>',
        { x => 42 },
        p(42),
        'builtins',
    ],
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), html_escape($out), $msg;
}

done_testing;
