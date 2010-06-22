#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(mark_raw);

my %funcs = (
    uc      => sub{ uc $_[0] },
    sprintf => sub{ sprintf shift, @_ },
    pi      => sub{ 3.14 },
    foo     => sub{ "<foo>" },
    em      => sub{ mark_raw("<em>@_</em>") },

    engine  => sub{ ref(Text::Xslate->engine) },
);
my $tx = Text::Xslate->new(
    function => \%funcs,
);

my @set = (
    [
        q{Hello, <:= $value | uc :> world!},
        { value => 'Xslate' },
        "Hello, XSLATE world!",
    ],
    [
        q{Hello, <:= uc($value) :> world!},
        { value => 'Xslate' },
        "Hello, XSLATE world!",
    ],
    [
        q{Hello, <:= uc($value) :> world!},
        { value => '<Xslate>' },
        "Hello, &lt;XSLATE&gt; world!",
    ],
    [
        q{Hello, <:= sprintf('<%s>', $value) :> world!},
        { value => 'Xslate' },
        "Hello, &lt;Xslate&gt; world!",
    ],
    [
        q{Hello, <:= sprintf('<%s>', $value | uc) :> world!},
        { value => 'Xslate' },
        "Hello, &lt;XSLATE&gt; world!",
    ],
    [
        q{Hello, <:= sprintf('<%s>', uc($value)) :> world!},
        { value => 'Xslate' },
        "Hello, &lt;XSLATE&gt; world!",
    ],
    [
        q{Hello, <:= sprintf('%s and %s', $a, $b) :> world!},
        { a => 'Xslate', b => 'Perl' },
        "Hello, Xslate and Perl world!",
    ],
    [
        q{Hello, <:= sprintf('%s and %s', uc($a), uc($b)) :> world!},
        { a => 'Xslate', b => 'Perl' },
        "Hello, XSLATE and PERL world!",
    ],
    [
        q{Hello, <:= pi() :> world!},
        { value => 'Xslate' },
        "Hello, 3.14 world!",
    ],

    [
        q{Hello, <:= foo() :> world!},
        { value => 'Xslate' },
        "Hello, &lt;foo&gt; world!",
    ],

    [
        q{Hello, <:= em($value) :> world!},
        { value => 'Xslate' },
        "Hello, <em>Xslate</em> world!",
    ],

    [
        q{Hello, <:= engine() :> world!},
        {  },
        "Hello, Text::Xslate world!",
    ],
);

foreach my $d(@set) {
    my($in, $vars, $out) = @$d;
    is $tx->render_string($in, $vars), $out or diag $in;
}

done_testing;
