#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);

my $tx = Text::Xslate->new();

my @data = (
    ['Hello, world!' => 'Hello, world!'],
    ['Hello, <: $lang :> world!' => 'Hello, Xslate world!'],
    ['Hello, <: $foo :> world!' => 'Hello, &lt;bar&gt; world!'],
    ['<: $lang :> <: $foo :> <: $lang :> <: $foo :>' => 'Xslate &lt;bar&gt; Xslate &lt;bar&gt;'],
    [q{<:$lang:>}, 'Xslate'],
    [q{foo <:= $lang
        :> bar} => "foo Xslate bar"],
    [q{<: print $lang :>} => "Xslate"],
    [q{<:print $lang:>}   => "Xslate"],
    [q{<:print$lang:>}    => "Xslate"],
    [q{<:print $lang, "\n":>} => "Xslate\n"],

    [q{<:print "<", $lang, ">":>} => "&lt;Xslate&gt;"],
    [q{<:print_raw "<", $lang, ">":>} => "<Xslate>"],
);

my %vars     = (lang => 'Xslate', foo => "<bar>");
my $vars_str = p(\%vars);
foreach my $pair(@data) {
    my($in, $out) = @$pair;

    #diag $in;
    is $tx->render_string($in, \%vars), $out or diag $in;

    is p(\%vars), $vars_str, 'vars are not changed';
}

done_testing;
