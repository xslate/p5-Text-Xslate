#!perl -w
use strict;
use Test::More;

use Text::Xslate qw(
    mark_raw
    unmark_raw
    escaped_string
    html_escape
);

sub r {
    return Text::Xslate::Type::Raw->new(@_);
}

my $tx = Text::Xslate->new();

my @set = (
    [<<'T', {lang => '<Xslate>'}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => r('&lt;Xslate&gt;')}, <<'X', 'T::X::T::R->new()'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => escaped_string('&lt;Xslate&gt;')}, <<'X', 'escaped_string()'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => escaped_string(escaped_string('&lt;Xslate&gt;'))}, <<'X', "nested"],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => mark_raw('&lt;Xslate&gt;')}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => mark_raw(mark_raw('&lt;Xslate&gt;'))}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => unmark_raw('<Xslate>')}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => unmark_raw(mark_raw('<Xslate>'))}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => r(r(r('&lt;Xslate&gt;')))}, <<'X', 'T::X::T::R->new()'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => unmark_raw(r(r(r('<Xslate>'))))}, <<'X', 'T::X::T::R->new()'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

    [<<'T', {lang => html_escape('<Xslate>')}, <<'X'],
    Hello, <: $lang :>, world!
T
    Hello, &lt;Xslate&gt;, world!
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}

is     escaped_string('&lt;Xslate&gt;'),       '&lt;Xslate&gt;', "raw strings can be stringified";
cmp_ok escaped_string('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;', "raw strings are comparable";

is     mark_raw('&lt;Xslate&gt;'),       '&lt;Xslate&gt;', "raw strings can be stringified";
cmp_ok mark_raw('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;', "raw strings are comparable";

is     unmark_raw('&lt;Xslate&gt;'),       '&lt;Xslate&gt;';
cmp_ok unmark_raw('&lt;Xslate&gt;'), 'eq', '&lt;Xslate&gt;';

is html_escape(q{ & ' " < > }),  qq{ &amp; &apos; &quot; &lt; &gt; }, 'html_escape()';
is html_escape('<Xslate>'), '&lt;Xslate&gt;', 'html_escape()';
is html_escape(html_escape('<Xslate>')), '&lt;Xslate&gt;', 'duplicated html_escape()';

done_testing;
