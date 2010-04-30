#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use lib "t/lib";

my @data = (
    ['Hello, <%= $lang %> world!' => 'Hello, Xslate world!'],
    ['Hello, <%= $foo %> world!' => 'Hello, &lt;bar&gt; world!'],
    [q{foo <%= $lang
        %> bar} => "foo Xslate bar"],

    # no default
    ['Hello, <: $lang :> world!' => 'Hello, <: $lang :> world!'],
    [':= $lang', ':= $lang'],

    # no line code
    ['%= $lang', '%= $lang'],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;
    my %vars = (lang => 'Xslate', foo => "<bar>");

    my $x = Text::Xslate->new(
        syntax => 'Foo',
        string => $in,
    );

    is $x->render(\%vars), $out, $in;

    $x = Text::Xslate->new(
        syntax => 'Text::Xslate::Syntax::Foo', # fullname is ok
        string => $in,
    );

    is $x->render(\%vars), $out, $in;
}

done_testing;
