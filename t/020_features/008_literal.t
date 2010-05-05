#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    [ '<: "foo" :>',    "foo"],
    [q{<: 'bar' :>},    "bar"],

    ['<: 42 :>',       42],
    ['<: 1.23 :>',     1.23 ],
    ['<: 1_23 :>',     1_23 ],
    ['<: 1_23.1_2 :>', 1_23.1_2 ],

    ['<: "\n\n" :>',     "\n\n" ],
    ['<: "\r\r" :>',     "\r\r" ],
    ['<: "\t\t" :>',     "\t\t" ],
    ['<: "\"\"" :>',     "&quot;&quot;" ],
    ['<: "\+\+" :>',     "\+\+" ],
    ['<: "\\\\\\\\" :>',     "\\\\" ],
    ['<: "<:$foo:>" :>', '&lt;:$foo:&gt;' ],

    [q{<: '\n\n' :>}, '\n\n' ],
    [q{<: '\\\\\\\\' :>}, '\\\\' ],
    [q{<: '\'\'' :>}, '&#39;&#39;' ],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;
    my %vars;
    is $tx->render_string($in, \%vars), $out or diag $in;
}

done_testing;
