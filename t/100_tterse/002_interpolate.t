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

    ['Hello, [% $no_such_field %] world!' => 'Hello,  world!', 'nil as empty'],
    ['Hello, [% $no_such_field or "Default" %] world!' => 'Hello, Default world!', 'empty or default'],
);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    my %vars = (lang => 'Xslate', foo => "<bar>", '$lang' => 'XXX');

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
