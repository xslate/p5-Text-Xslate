#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use lib "t/lib";

# moniker
my $tx1 = Text::Xslate->new(syntax => 'Foo');
# fq name
my $tx2 = Text::Xslate->new(syntax => 'Text::Xslate::Syntax::Foo');

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

    is $tx1->render_string($in, \%vars), $out, $in;
    is $tx2->render_string($in, \%vars), $out, $in;
}

done_testing;
