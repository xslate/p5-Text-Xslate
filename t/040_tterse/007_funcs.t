#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my %funcs = (
    uc      => sub { uc $_[0] },
    sprintf => sub { sprintf shift, @_ },
    pi      => sub { 3.14 },
    last    => sub { 'last' }, # lower cased keyword
    IF      => sub { 'IF'  },  # upper cased keyword
);
my $tx = Text::Xslate->new(
    syntax   => 'TTerse',
    function => \%funcs,
);

my @set = (
    [
        q{Hello, [% $a | uc %] world!},
        "Hello, XSLATE world!",
    ],
    [
        q{Hello, [% uc($a) %] world!},
        "Hello, XSLATE world!",
    ],
    [
        q{Hello, [% uc($b) %] world!},
        "Hello, &lt;XSLATE&gt; world!",
    ],
    [
        q{Hello, [% sprintf('<%s>', $a) %] world!},
        "Hello, &lt;Xslate&gt; world!",
    ],
    [
        q{Hello, [% sprintf('<%s>', $a | uc) %] world!},
        "Hello, &lt;XSLATE&gt; world!",
    ],
    [
        q{Hello, [% sprintf('<%s>', uc($a)) %] world!},
        "Hello, &lt;XSLATE&gt; world!",
    ],
    [
        q{Hello, [% sprintf('%s and %s', $a, $b) %] world!},
        "Hello, Xslate and &lt;Xslate&gt; world!",
    ],
    [
        q{Hello, [% sprintf('%s and %s', uc($a), uc($b)) %] world!},
        "Hello, XSLATE and &lt;XSLATE&gt; world!",
    ],
    [
        q{Hello, [% pi() %] world!},
        "Hello, 3.14 world!",
    ],

    [
        q{Hello, [% GET last() %] world!},
        "Hello, last world!",
    ],

    [
        q{Hello, [% GET IF() %] world!},
        "Hello, IF world!",
    ],
);
my %vars = (
    a =>  'Xslate',
    b => '<Xslate>',
);
foreach my $d(@set) {
    my($in, $out) = @$d;
    is $tx->render_string($in, \%vars), $out or diag $in;
}

eval {
    my $tx = Text::Xslate->new( syntax => 'TTerse', warn_handler => sub{ die @_ } );
    $tx->render_string("[% foobar() %]");
};
like $@, qr/Undefined function/;
like $@, qr/\b foobar \b/xms;

done_testing;
