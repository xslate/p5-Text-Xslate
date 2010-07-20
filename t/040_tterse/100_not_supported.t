#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    [<<'T'],
[% PERL %]
print "Hello, world"\n";
[% PERL %]
T

    [<<'T'],
[% TRY %]
print "Hello, world"\n";
[% END %]
T
);

my %vars = (
    lang => 'Xslate',
    void => '',

    value => 10,
);
foreach my $d(@data) {
    my($in, $out, $msg) = @$d;
    eval { render_str($in, \%vars) };
    note $@;
    like $@, qr/not supported/;
}

done_testing;
