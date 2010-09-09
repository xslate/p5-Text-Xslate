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
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => r('&lt;Xslate&gt;')}, <<'X', 'T::X::T::R->new()'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => escaped_string('&lt;Xslate&gt;')}, <<'X', 'escaped_string()'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => escaped_string(escaped_string('&lt;Xslate&gt;'))}, <<'X', "nested"],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => mark_raw('&lt;Xslate&gt;')}, <<'X'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => mark_raw(mark_raw('&lt;Xslate&gt;'))}, <<'X'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => unmark_raw('<Xslate>')}, <<'X'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => unmark_raw(mark_raw('<Xslate>'))}, <<'X'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => r(r(r('&lt;Xslate&gt;')))}, <<'X', 'T::X::T::R->new()'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => unmark_raw(r(r(r('<Xslate>'))))}, <<'X', 'T::X::T::R->new()'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => html_escape('<Xslate>')}, <<'X'],
    Hello, <: $lang :> world!
T
    Hello, &lt;Xslate&gt; world!
X

    [<<'T', {lang => mark_raw('<Xslate>'), l => '<', g => '>'}, <<'X', 'smart concat'],
    Hello, <:      $l ~ $lang ~ $g :> world!
    Hello, <: html($l ~ $lang ~ $g) :> world!
    Hello, <: html($l) ~ $lang ~ html($g) :> world!
T
    Hello, &lt;<Xslate>&gt; world!
    Hello, &lt;<Xslate>&gt; world!
    Hello, &lt;<Xslate>&gt; world!
X

    [<<'T', {lang => mark_raw('<Xslate>')}, <<'X', 'smart repeat'],
    Hello, <: $lang x 1 :> world!
    Hello, <: $lang x 2 :> world!
T
    Hello, <Xslate> world!
    Hello, <Xslate><Xslate> world!
X
);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;
    is $tx->render_string($in, $vars), $out, $msg or diag $in;
}

done_testing;
