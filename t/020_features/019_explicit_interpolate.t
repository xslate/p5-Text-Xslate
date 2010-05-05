#!perl -w
use strict;
use Test::More;

use Text::Xslate;

my $tx = Text::Xslate->new();

my @data = (
    ['Hello, world!' => 'Hello, world!'],
    ['Hello, <:= $lang :> world!' => 'Hello, Xslate world!'],
    ['Hello, <:= $foo :> world!' => 'Hello, &lt;bar&gt; world!'],
    ['<:= $lang :> <:= $foo :> <:= $lang :> <:= $foo :>' => 'Xslate &lt;bar&gt; Xslate &lt;bar&gt;'],
    [q{foo <:= $lang
        :> bar} => "foo Xslate bar"],
    [q{<: print $lang :>} => "Xslate"],
    [q{<:print $lang:>} => "Xslate"],
    [q{<:print $lang, "\n":>} => "Xslate\n"],
    [q{<:print "<", $lang, ">":>} => "&lt;Xslate&gt;"],
    [q{<:print_raw "<", $lang, ">":>} => "<Xslate>"],

    ['<:= "foo\tbar\n" :>', "foo\tbar\n"],
    [q{<:= 'foo\tbar\n' :>}, 'foo\tbar\n'],
    [q{<:= ' & " \' ' :>}, ' &amp; &quot; &#39; '],

    [q{foo<:# this is a comment :>bar}, "foobar"],
    [q{<:=$lang:> foo<:# this is a comment :>bar <:=$lang:>}, "Xslate foobar Xslate"],
    [q{foo<:
        :>bar}, "foobar"],
    [q{foo<: # this is a comment
        $lang :>bar}, "fooXslatebar"],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;
    my %vars = (lang => 'Xslate', foo => "<bar>");

    is $tx->render_string($in, \%vars), $out or diag $in;
}

done_testing;
