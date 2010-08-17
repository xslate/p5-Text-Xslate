#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    ['Hello, [% lang or "Perl" %] world!'  => 'Hello, Xslate world!'],
    ['Hello, [% empty or "Perl" %] world!' => 'Hello, Perl world!'],

    ['Hello, [% "foo" _ "bar" %] world!' => 'Hello, foobar world!'],

    ['[% ( NOT value == 10 ) ? "true" : "false" %]', "false" ],
    ['[% (NOT value AND (value == 10)) ? "true" : "false" %]', "false" ],
    ['[% (NOT( value == 10 ))  ? "true" : "false" %]', "false", ],

    ['[% (value == 10 AND value == 10) ? "true" : "false" %]', "true" ],
    ['[% (value == 10) AND (value == 10) ? "true" : "false" %]', "true" ],

    ['[% (value == 10 AND value == 10 OR value == 10) ? "true" : "false" %]', "true" ],
    ['[% ((value == 10) AND (value == 10) OR (value == 10)) ? "true" : "false" %]', "true" ],
    ['[% (value == 10 AND value == 10 OR value == 11) ? "true" : "false" %]', "true" ],
    ['[% (((value == 10) AND (value == 10)) OR  (value == 11)) ? "true" : "false" %]', "true" ],

    # TTerse specific features
    ['[% 0x110 +& 0x101 %]', 0x100, undef, 1 ],
);

my %vars = (
    lang    => 'Xslate',
    foo     => "<bar>",
    '$lang' => 'XXX',
    value   => 10,
);
foreach my $d(@data) {
    my($in, $out, $msg, $is_tterse_specific) = @$d;

    last if $is_tterse_specific;
    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
