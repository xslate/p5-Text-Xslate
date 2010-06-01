#!perl -w
use strict;
use Test::More;

use t::lib::TTSimple;

my @data = (
    [<<'T', <<'X'],
[% MACRO foo BLOCK -%]
    Hello, [% lang %] world!
[% END -%]
[% foo() -%]
T
    Hello, Xslate world!
X

    [<<'T', <<'X'],
[% MACRO foo(lang) BLOCK -%]
    foo [% lang %] bar
[% END -%]
    [%- foo(42) -%]
    Hello, [% lang %] world!
T
    foo 42 bar
    Hello, Xslate world!
X

    [<<'T', <<'X'],
[% MACRO add(a, b) BLOCK -%]
    [% a + b %]
[% END -%]
    [%- add(10, 32) -%]
T
    42
X

);

foreach my $pair(@data) {
    my($in, $out, $msg) = @$pair;

    my %vars = (lang => 'Xslate', foo => "<bar>", '$lang' => 'XXX');

    is render_str($in, \%vars), $out, $msg
        or diag $in;
}

done_testing;
