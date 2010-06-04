#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;
use Text::Xslate::Util qw(p);

my @data = (
    [<<'T', <<'X'],
[% SET i = 0 -%]
[% WHILE i < 3 -%]
    [% i %]
[% i = i + 1 -%]
[% END -%]
T
    0
    1
    2
X


);

my %vars = (lang => 'Xslate', foo => '<bar>', '$lang' => 'XXX');

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
