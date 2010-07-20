#!perl -w
use strict;
use Test::Requires qw(Template::Plugin::Math);
use Test::More;

use t::lib::TTSimple;

use Template::Plugin::String;

# XXX: TTerse does not support plugins (i.e. USE directive), but grokes
#      the USE keyword as an alias to 'CALL', which takes expressions.

my @data = (
    [<<'T', <<'X'],
[% USE Math -%]
    [% Math.abs(-100) %]
    [% Math.abs( 100) %]
T
    100
    100
X

    [<<'T', <<'X'],
[% USE String -%]
[% s = String.new("foo") -%]
    [% s.upper %]
    [% s.repeat(2) %]
T
    FOO
    FOOFOO
X

);

my %vars = (
    lang => 'Xslate',
    void => '',

    value => 10,

    Math   => Template::Plugin::Math->new(),   # as a namespace
    String => Template::Plugin::String->new(), # as a prototype
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;
    is render_str($in, \%vars), $out, $msg or diag($in);
}

done_testing;
