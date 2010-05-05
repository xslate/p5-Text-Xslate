#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Parser;

my $myparser = Text::Xslate::Parser->new(
    line_start => undef,
    tag_start  => qr/\Q[%/xms,
    tag_end    => qr/\Q%]/xms,
);

my $tx = Text::Xslate->new(
    syntax => $myparser,
);

my @data = (
    ['Hello, [%= $lang %] world!' => 'Hello, Xslate world!'],
    ['Hello, [%= $foo %] world!' => 'Hello, &lt;bar&gt; world!'],
    [q{foo [%= $lang
        %] bar} => "foo Xslate bar"],

    # no default
    ['Hello, <: $lang :> world!' => 'Hello, <: $lang :> world!'],
    [":= \$lang\n", ":= \$lang\n"],

    # no line code
    ["%= \$lang\n", "%= \$lang\n"],
);

foreach my $pair(@data) {
    my($in, $out) = @$pair;

    my %vars = (lang => 'Xslate', foo => "<bar>");

    is $tx->render_string($in, \%vars), $out, $in;
}

done_testing;
