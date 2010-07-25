#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    ['Hello, [% lang or "Perl" %] world!'  => 'Hello, Xslate world!'],
    ['Hello, [% empty or "Perl" %] world!' => 'Hello, Perl world!'],

    ['Hello, [% "foo" _ "bar" %] world!' => 'Hello, foobar world!'],

    ['[% lang.defined()        ? "d" : "!d" %]' => 'd'],
    ['[% no_such_var.defined() ? "d" : "!d" %]' => '!d'],

    ['[% ( NOT $lang == "Xslate" ) ? "true" : "false" %]', "false" ],
    ['[% (NOT $lang AND ($lang == "Xslate")) ? "true" : "false" %]', "false" ],
    ['[% (NOT( $lang == "Xslate" ))  ? "true" : "false" %]', "false", ],

    ['[% ($lang == "Xslate" AND $value) ? "true" : "false" %]', "true" ],
    ['[% ($lang == "Xslate") AND $value ? "true" : "false" %]', "true" ],

    ['[% ($lang == "Xslate" AND $value == 10 OR $value == 10) ? "true" : "false" %]', "true" ],
    ['[% (($lang == "Xslate") AND ($value == 10) OR ($value == 10)) ? "true" : "false" %]', "true" ],
    ['[% ($lang == "Xslate" AND $value == 10 OR $value == 11) ? "true" : "false" %]', "true" ],
    ['[% (($lang == "Xslate") AND ($value == 10) OR  ($value == 11)) ? "true" : "false" %]', "true" ],

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
