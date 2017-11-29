#!perl -w
use strict;
use Test::More;

use lib "t/lib";
use TTSimple;
use Text::Xslate::Util qw(p);

my @data = (
    [<<'T', <<'X'],
foo
[% CALL lang -%]
[% CALL foo.bar -%]
bar
T
foo
bar
X

    [<<'T', <<'X', 'lower cased'],
foo
[% call lang -%]
[% call foo.bar -%]
bar
T
foo
bar
X

);

my %vars = (lang => 'Xslate', foo => { bar => 43 });

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
