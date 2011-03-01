#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    ['<: "foo\tbar\n" :>', "foo\tbar\n"],
    [q{<: 'foo\tbar\n' :>}, 'foo\tbar\n'],
    [q{<: ' & " \' ' :>}, ' &amp; &quot; &#39; '],
    [q{<: "<: 'foo' :>" :>}, "&lt;: &#39;foo&#39; :&gt;"],

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

    # from Template::Benchmark
    [<<'T' x 10, <<'X' x 10],
<: for $hash.keys() ->($k) { :><:= $k :><:= ":" :> <:= $hash[ $k ] :><: } :>
T
age: 43name: Larry Nomates
X

);

my %vars = (
    lang => 'Xslate',
    foo => "<bar>",
    hash => { name => 'Larry Nomates', age => 43,  },
);
foreach my $pair(@data) {
    my($in, $out) = @$pair;
    is $tx->render_string($in, \%vars), $out
        or diag $in;
}

done_testing;
