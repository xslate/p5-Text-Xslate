#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(escaped_string);

my $tx = Text::Xslate->new();

my @set = (
    [<<'T', {lang => '<Xslate>'}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => Text::Xslate::EscapedString->new('&lt;Xslate&gt;')}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => escaped_string('&lt;Xslate&gt;')}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => escaped_string(escaped_string('&lt;Xslate&gt;'))}, <<'X', "nested"],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg || $in;
}

is escaped_string('&lt;Xslate&gt;'), '&lt;Xslate&gt;', "escaped strings can be stringified";
cmp_ok escaped_string('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;', "escaped strings are comparable";

done_testing;
