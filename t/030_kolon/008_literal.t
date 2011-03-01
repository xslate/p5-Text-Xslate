#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    [ '<: "foo" :>',    "foo"],
    [q{<: 'bar' :>},    "bar"],

    ['<: 0 :>',          0],
    ['<: 42 :>',         42],
    ['<: 0.01 :>',       0.01 ],
    ['<: 1.23 :>',       1.23 ],
    ['<: 1_23 :>',       1_23 ],
    ['<: 1_23.1_2 :>',   1_23.1_2 ],
    ['<: 00777  :>',     00777  ],
    ['<: 0xCAFE :>',     0xCAFE ],
    ['<: 0b1010 :>',     0b1010 ],
    ['<: 00_7_7_7  :>',  00777  ],
    ['<: 0x_C_A_F_E :>', 0xCAFE ],
    ['<: 0b_1_0_1_0 :>', 0b1010 ],

    ['<: -10 :>',        -10 ],
    ['<: +10 :>',        +10 ],

    ['<: "-10" :>',     "-10" ],
    ['<: "+10" :>',     "+10" ],

    ['<: "-10.0" :>',     "-10.0" ],
    ['<: "+10.0" :>',     "+10.0" ],

    ['<: "\n\n" :>',     "\n\n" ],
    ['<: "\r\r" :>',     "\r\r" ],
    ['<: "\t\t" :>',     "\t\t" ],
    ['<: "\"\"" :>',     "&quot;&quot;" ],
    ['<: "\+\+" :>',     "\+\+" ],
    ['<: "\\\\\\\\" :>',     "\\\\" ],
    ['<: "<:$foo:>" :>', '&lt;:$foo:&gt;' ],
    ['<: "foo@example.com" :>', 'foo@example.com' ],

    [q{<: '\n\n' :>}, '\n\n' ],
    [q{<: '\\\\\\\\' :>}, '\\\\' ],
    [q{<: '\'\'' :>}, '&#39;&#39;' ],

    [q{<: 'foo="bar"' :>},          'foo=&quot;bar&quot;' ],
    [qq{<: 'foo\n"bar"\nbaz' :>}, qq{foo\n&quot;bar&quot;\nbaz}],

    [q{<: "foo='bar'" :>},          'foo=&#39;bar&#39;' ],
    [qq{<: "foo\n'bar'\nbaz" :>}, qq{foo\n&#39;bar&#39;\nbaz}],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;
    my %vars;
    is $tx->render_string($in, \%vars), $out or diag $in;
}

ok  $tx->render_string("<: true  :>");
ok !$tx->render_string("<: false :>");

done_testing;
