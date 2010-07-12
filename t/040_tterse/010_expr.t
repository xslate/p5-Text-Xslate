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
);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    my %vars = (lang => 'Xslate', foo => "<bar>", '$lang' => 'XXX');

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
