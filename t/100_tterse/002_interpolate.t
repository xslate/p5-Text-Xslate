#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    ['Hello, world!' => 'Hello, world!'],
    ['Hello, [% lang %] world!' => 'Hello, Xslate world!'],
    ['Hello, [% foo %] world!'  => 'Hello, &lt;bar&gt; world!'],
    ['Hello, [% lang %] [% foo %] world!'
                                 => 'Hello, Xslate &lt;bar&gt; world!'],

    ['Hello, [% $lang %] world!' => 'Hello, Xslate world!'],

);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my %vars = (lang => 'Xslate', foo => "<bar>");

    is render_str($in, \%vars), $out, $in for 1 .. 2;
}

done_testing;
