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

    engine  => sub{ ref(Text::Xslate->current_engine) },
    fetch   => sub{ Text::Xslate->current_vars->{ $_[0] } },
    file    => sub{ Text::Xslate->current_file },
    line    => sub{ Text::Xslate->current_line },
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

    [
        q{<: file() :>},
        {},
        '&lt;string&gt;',
    ],
    [
        q{<: line() :>},
        {},
        '1',
    ],
    [
        qq{\n\n<: line() :>\n\n<: line() :>},
        {},
        qq{\n\n3\n\n5},
    ],
    [
        qq{-<: fetch('foo') :>-},
        { foo => 'bar' },
        qq{-bar-},
    ],
    [
        qq{-<: fetch('FOO') // 'BAR' :>-},
        { foo => 'bar' },
        qq{-BAR-},
    ],
);

foreach my $d(@set) {
    my($in, $vars, $out) = @$d;
    is $tx->render_string($in, $vars), $out or diag $in;
}

is(Text::Xslate->current_engine, undef);
is(Text::Xslate->current_vars,   undef);
is(Text::Xslate->current_file,   undef);
is(Text::Xslate->current_line,   undef);

done_testing;
