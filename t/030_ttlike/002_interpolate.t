#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use Data::Dumper;

my $tx = Text::Xslate->new(
    syntax => 'TTLike',
);

my @data = (
    ['Hello, world!' => 'Hello, world!'],
    ['Hello, [% lang %] world!' => 'Hello, Xslate world!'],
    ['Hello, [% foo %] world!'  => 'Hello, &lt;bar&gt; world!'],
    ['Hello, [% lang %] [% foo %] world!'
                                 => 'Hello, Xslate &lt;bar&gt; world!']
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my $x = $tx->compile_str($in);

    my %vars = (lang => 'Xslate', foo => "<bar>");

    is $x->render(\%vars), $out, 'first';
    is $x->render(\%vars), $out, 'second';
}

done_testing;
