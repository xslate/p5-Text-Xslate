#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    ['<: "foo\tbar\n" :>', "foo\tbar\n"],
    [q{<: 'foo\tbar\n' :>}, 'foo\tbar\n'],
    [q{<: ' & " \' ' :>}, ' &amp; &quot; &apos; '],
    [q{<: "<: 'foo' :>" :>}, "&lt;: &apos;foo&apos; :&gt;"],

    [q{foo<:# this is a comment :>bar}, "foobar"],
    [q{<:$lang:> foo<:# this is a comment :>bar <:$lang:>}, "Xslate foobar Xslate"],
    [q{foo<:
        :>bar}, "foobar"],
    [q{foo<: # this is a comment
        $lang :>bar}, "fooXslatebar"],

    # edge-cases
    [q{: $lang}, 'Xslate'],
    [q{<: $lang :>:}, 'Xslate:' ],

    [<<'T', <<'X' ],
<: $lang :>
: "foo\n"
T
Xslate
foo
X

    [<<'T', <<'X' ],
<: $lang :>: 42
T
Xslate: 42
X

    [<<'T', 42 ],
: for [42] -> $it {
: $it
: }
T

);

my %vars = (lang => 'Xslate', foo => "<bar>");
foreach my $pair(@data) {
    my($in, $out) = @$pair;
    is $tx->render_string($in, \%vars), $out
        or diag $in;
}

done_testing;
