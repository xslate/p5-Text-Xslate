#!perl -w

use strict;
use Test::More;

use Text::Xslate::Compiler;


my $c = Text::Xslate::Compiler->new(
    parser => Text::Xslate::Parser->new(
        line_start => undef,
        tag_start  => qr/\Q[%/xms,
        tag_end    => qr/\Q%]/xms,
    ),
);

isa_ok $c, 'Text::Xslate::Compiler';

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

    my $x = $c->compile_str($in);

    my %vars = (lang => 'Xslate', foo => "<bar>");

    $in =~ s/\n/\\n/g;
    is $x->render(\%vars), $out, $in;
}

done_testing;
