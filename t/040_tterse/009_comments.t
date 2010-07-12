#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    [ <<'T', <<'X', ],
A[%# foo %]B
T
AB
X

    [ <<'T', <<'X', ],
A[%#
    foo
%]B
T
AB
X

    [ <<'T', <<'X', ],
A[%#
        [foo]
        [bar]
        [baz]
%]B
T
AB
X
);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my %vars = ();
    is render_str($in, \%vars), $out, $msg or diag $in;
}

done_testing;
