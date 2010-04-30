#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;
use Text::Xslate::Parser::TTerse;

my $tx = Text::Xslate::Compiler->new(
    parser => Text::Xslate::Parser::TTerse->new(),
);

my @data = (
    ['Hello, world!' => 'Hello, world!'],
    ['Hello, [% lang %] world!' => 'Hello, Xslate world!'],
    ['Hello, [% foo %] world!'  => 'Hello, &lt;bar&gt; world!'],
    ['Hello, [% lang %] [% foo %] world!'
                                 => 'Hello, Xslate &lt;bar&gt; world!']
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (lang => 'Xslate', foo => "<bar>");

    is $x->render(\%vars), $out, $in for 1 .. 2;
}

done_testing;
